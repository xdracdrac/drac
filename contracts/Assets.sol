// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./common/BaseUpgradeable.sol";
import "./config/ConfigBase.sol";
import "./interface/IAssets.sol";
import "./util/Utils.sol";

contract Assets is BaseUpgradeable, IAssets {

    ///////////////////////////////// constant /////////////////////////////////
    ConfigBase public config;


    ///////////////////////////////// storage /////////////////////////////////
    // account => (assetsId => value)
    mapping(address => mapping(uint => uint)) private _assetsOf;


    ///////////////////////////////// upgrade /////////////////////////////////


    function initialize() public virtual initializer {
        __Assets_init();

    }

    function __Assets_init() internal initializer {
        BaseUpgradeable.__Base_init();

    }

    modifier isServing() {
        require(!isPaused, "!isPaused");
        require(address(0) != address(config), "address(0) != address(config)");
        _;
    }

    function setConfig(address _value) external onlyAdmin {
        config = ConfigBase(_value);
    }

    function assetsOf(address _account, uint _id) external view override returns (uint) {
        return _assetsOf[_account][_id];
    }

    function getAssets(address _account, uint[] memory _ids) external view override returns (uint[] memory res) {
        res = new uint[](_ids.length);
        for (uint i = 0; i < _ids.length; i++) {
            res[i] = _assetsOf[_account][_ids[i]];
        }
    }

    function setAssetsOf(address _account, uint _id, uint _value) external override onlyAuth {
        uint preValue = _assetsOf[_account][_id];
        if (0 == _value) {
            delete _assetsOf[_account][_id];
        } else {
            _assetsOf[_account][_id] = _value;
        }

        emit UpdateAssets(msg.sender, _account, _id, 3, _value, preValue, _assetsOf[_account][_id]);
    }

    function add(address _account, uint _id, uint _value) external override onlyAuth {
        uint preValue = _assetsOf[_account][_id];
        _addHook(_account, _id, _value);
        _assetsOf[_account][_id] += _value;

        emit UpdateAssets(msg.sender, _account, _id, 1, _value, preValue, _assetsOf[_account][_id]);
    }

    function sub(address _account, uint _id, uint _value) external override onlyAuth {
        uint preValue = _assetsOf[_account][_id];
        require(_assetsOf[_account][_id] >= _value, "sub: _assetsOf[_account][_id] >= _value");
        _subHook(_account, _id, _value);
        _assetsOf[_account][_id] -= _value;

        emit UpdateAssets(msg.sender, _account, _id, 0, _value, preValue, _assetsOf[_account][_id]);
    }

    function _addHook(address _account, uint _id, uint _value) internal virtual returns (bool) {
        // todo

        return true;
    }

    function _subHook(address _account, uint _id, uint _value) internal virtual returns (bool) {
        // todo

        return true;
    }

}
