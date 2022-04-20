// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interface/IUniswapV2Pair.sol";
import "./interface/IUniswapV2Factory.sol";
import "./interface/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

abstract contract Base {
    address public admin;
    // auth account
    mapping(address => bool) public auth;

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "onlyAdmin");
        _;
    }

    modifier onlyAuth() {
        require(auth[msg.sender], "onlyAuth");
        _;
    }

    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    function setAuth(address _account, bool _authState) external onlyAdmin {
        require(auth[_account] != _authState, "setAuth: auth[_account] != _authState");
        auth[_account] = _authState;
    }

}

interface IDividendInviter {
    function bind(address from, address to, uint256 amount) external;
    function divBinder(address from, uint256 amount) external;
    function withdrawDividend(address account) external;
}

interface IPoolLP {
    function dividend(address from, address to, uint256 amount) external;
}

contract DRACToken is ERC20, Base {

    ///////////////////////////////// constant /////////////////////////////////
    // todo: router address
    IUniswapV2Router02 public constant ROUTER = IUniswapV2Router02(0xA902619D86c37F1c797D3CE1e449e7061bc6E0A1);
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address public lpToken;
    address public opFund;
    address public wallet;
    IDividendInviter public dividendInviter;
    IPoolLP public poolLP;

    uint constant MAX_SUPPLY = 480_000_000 ether;

    uint constant RATE_BINDER = 500;
    uint constant RATE_LP = 200;
    uint constant RATE_WALLET = 200;

    ///////////////////////////////// storage /////////////////////////////////
    mapping(address => bool) private _isExcludedFromFee;



    constructor() ERC20("Dragon Token", "DRAC") {
        _mint(msg.sender, MAX_SUPPLY);
        lpToken = IUniswapV2Factory(ROUTER.factory()).createPair(address(this), USDT);

        //exclude owner and this contract from fee
        _isExcludedFromFee[msg.sender] = true;
        _isExcludedFromFee[address(this)] = true;
    }

    receive() external payable {}

    function setOpFun(address _value) external onlyAdmin {
        opFund = _value;
        _isExcludedFromFee[_value] = true;
    }

    function setWallet(address _value) external onlyAdmin {
        wallet = _value;
        _isExcludedFromFee[_value] = true;
    }

    function setDividendInviter(address _value) external onlyAdmin {
        dividendInviter = IDividendInviter(_value);
        _isExcludedFromFee[_value] = true;
    }

    function setPoolLP(address _value) external onlyAdmin {
        poolLP = IPoolLP(_value);
        _isExcludedFromFee[_value] = true;
    }

    function excludeFromFee(address _index, bool _value) public onlyAdmin {
        _isExcludedFromFee[_index] = _value;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0 || _isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            super._transfer(from, to, amount);
            return;
        }

        if (from == lpToken) {
            uint amount1 = amount * RATE_BINDER / 10000;
            super._transfer(from, address(dividendInviter), amount1);
            dividendInviter.divBinder(to, amount);

            uint amount2 = amount * RATE_LP / 10000;
            super._transfer(from, address(poolLP), amount2);
            poolLP.dividend(from, to, amount2);

            uint amount3 = amount * RATE_WALLET / 10000;
            super._transfer(from, wallet, amount3);

            super._transfer(from, to, amount - amount1 - amount2 - amount3);
        } else if (to == lpToken) {
            if (0 == balanceOf(lpToken)) {
                require(from == opFund, "ERC20: only opFund");
                super._transfer(from, to, amount);
                return;
            }

            uint amount1 = amount * RATE_BINDER / 10000;
            super._transfer(from, address(dividendInviter), amount1);
            dividendInviter.divBinder(from, amount);

            uint amount2 = amount * RATE_LP / 10000;
            super._transfer(from, address(poolLP), amount2);
            poolLP.dividend(from, to, amount2);

            uint amount3 = amount * RATE_WALLET / 10000;
            super._transfer(from, wallet, amount3);

            super._transfer(from, to, amount - amount1 - amount2 - amount3);
        } else {
            super._transfer(from, to, amount);
            dividendInviter.bind(from, to, amount);
        }
    }

}