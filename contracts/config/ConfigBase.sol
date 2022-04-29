// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../common/BaseUpgradeable.sol";


contract ConfigBase is BaseUpgradeable {

    // contract => configName
    mapping(address => bytes) public contractOf;
    // configName => config
    mapping(bytes => address) public configNameOf;


    function initialize() public initializer {
        BaseUpgradeable.__Base_init();
    }

    function setContractOf(address _index, bytes memory _value) external onlyAdmin {
        contractOf[_index] = _value;
    }

    function setConfigNameOf(bytes memory _index, address _value) external onlyAdmin {
        configNameOf[_index] = _value;
    }

    function nameOf(bytes memory _name) public view returns (address) {
        address contractAddress = configNameOf[_name];
        require(address(0) != contractAddress, string(abi.encodePacked("001101:", _name)));
        return contractAddress;
    }

    function getUint(bytes memory _config, bytes memory _key, uint _id) public view returns (uint) {
        return abi.decode(getBytes(_config, _key, _id), (uint));
    }

    function getUintArray(bytes memory _config, bytes memory _key, uint _id) public view returns (uint[] memory) {
        return abi.decode(getBytes(_config, _key, _id), (uint[]));
    }

    function getUintArray2(bytes memory _config, bytes memory _key, uint _id) public view returns (uint[][] memory) {
        return abi.decode(getBytes(_config, _key, _id), (uint[][]));
    }

    function getBytes(bytes memory _config, bytes memory _key, uint _id) public view returns (bytes memory) {
        address config = configNameOf[_config];
        require(address(0) != config, string(abi.encodePacked("001101:", _config)));
        return get(config, _key, _id);
    }

    function get(address _config, bytes memory _key, uint _id) public view returns (bytes memory) {
        string memory methodName = string(abi.encodePacked("get_", _key, "(uint256)"));
        (bool success, bytes memory returnData) = _config.staticcall(abi.encodeWithSignature(methodName, _id));
        require(success, string(abi.encodePacked("001001:", _key)));
        return returnData;
    }

    function ids(bytes memory _config) public view returns (uint[] memory) {
        address config = configNameOf[_config];
        require(address(0) != config, string(abi.encodePacked("001101:", _config)));
        (bool success, bytes memory returnData) = config.staticcall(abi.encodeWithSignature("ids()"));
        require(success, string(abi.encodePacked("001001:", _config)));
        return abi.decode(returnData, (uint[]));
    }

}