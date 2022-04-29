// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./common/BaseUpgradeable.sol";
import "./config/ConfigBase.sol";
import "./interface/IUniswapV2Router02.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract DividendInviter is BaseUpgradeable {
    ///////////////////////////////// constant /////////////////////////////////
    ConfigBase public config;
    IUniswapV2Router02 public constant ROUTER = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address public token;


    ///////////////////////////////// storage /////////////////////////////////
    // child => inviter
    mapping(address => address) public parentOf;
    // parent => child_len
    mapping(address => uint) public childLenOf;


    event Bind(address indexed from, address to);
    event DivBinder(uint indexed id, address indexed account, uint amount);

    function initialize() public initializer {
        BaseUpgradeable.__Base_init();

    }

    function setConfig(address _value) external onlyAdmin {
        config = ConfigBase(_value);
    }

    function setToken(address _value) external onlyAdmin {
        token = _value;
        auth[token] = true;
    }

    function getParents(address _account, uint _num) public view returns (address[] memory) {
        address parent = parentOf[_account];
        address[] memory parents = new address[](_num);
        for (uint i; i < _num; i++) {
            parents[i] = parent;
            parent = parentOf[parent];
        }
        return parents;
    }

    function bind(address from, address to, uint256 amount) external onlyAuth {
        uint BIND_KEEP_AMOUNT = 0;
        uint BIND_TRANSFER_AMOUNT = 0;
        // limit check
        if (BIND_KEEP_AMOUNT > IERC20Upgradeable(token).balanceOf(from)) {return;}
        if (BIND_TRANSFER_AMOUNT > amount) {return;}

        // bind inviter
        if (from.code.length > 0 || to.code.length > 0) {return;}
        if (address(0) != parentOf[to]) {return;}
        if (0 < childLenOf[to]) {return;}
        parentOf[to] = from;
        childLenOf[from]++;

        emit Bind(from, to);
    }

    function divBinder(address from, uint256 amount) external onlyAuth {
        // update parent reward amount
        address parent = parentOf[from];
        if (address(0) == parent) {return;}
        uint[] memory genRate = config.getUintArray("InviterConf", "reward_transaction", 1);
        uint BIND_KEEP_AMOUNT = config.getUint("InviterConf", "bind_keep_amount", 1);
        for (uint i = 0; i < genRate.length; i++) {
            if (address(0) == parent) {break;}
            uint rewardAmount = amount * genRate[i] / 10000;
            uint parentBalance = IERC20Upgradeable(token).balanceOf(parent);
            if (0 < rewardAmount && BIND_KEEP_AMOUNT <= parentBalance) {
                IERC20Upgradeable(token).transfer(parent, rewardAmount);
                emit DivBinder(1, parent, rewardAmount);
            }
            parent = parentOf[parent];
        }
    }

    function divBinder2(address from, uint256 amount) external onlyAuth {
        // update parent reward amount
        address parent = parentOf[from];
        if (address(0) == parent) {return;}
        uint[] memory genRate = config.getUintArray("InviterConf", "reward_box", 1);
        for (uint i = 0; i < genRate.length; i++) {
            if (address(0) == parent) {break;}
            uint rewardAmount = amount * genRate[i] / 10000;
            if (0 < rewardAmount) {
                IERC20Upgradeable(config.nameOf("USDTToken")).transfer(parent, rewardAmount);
                emit DivBinder(2, parent, rewardAmount);
            }
            parent = parentOf[parent];
        }
    }

}
