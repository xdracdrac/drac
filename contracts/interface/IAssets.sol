// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IAssets {

    event UpdateAssets(address indexed from, address indexed account, uint indexed id, uint direction, uint value, uint preValue, uint currValue);

    function assetsOf(address _account, uint _id) external view returns (uint);

    function getAssets(address _account, uint[] memory _ids) external view returns (uint[] memory res);

    function setAssetsOf(address _account, uint _id, uint _value) external;

    function add(address _account, uint _id, uint _value) external;

    function sub(address _account, uint _id, uint _value) external;

}
