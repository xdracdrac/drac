// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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

contract DRACDAOToken is ERC20, Base {

    constructor(string memory name_, string memory symbol_, uint initalSupply_) ERC20(name_, symbol_) {
        _mint(msg.sender, initalSupply_ * 10 ** decimals());
        auth[msg.sender] = true;
    }
}