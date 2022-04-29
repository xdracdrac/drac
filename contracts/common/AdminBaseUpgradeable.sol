// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./BaseUpgradeable.sol";


abstract contract AdminBaseUpgradeable is BaseUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;


    ///////////////////////////////// admin function /////////////////////////////////
    event AdminWithdrawNFT(address operator, address indexed tokenAddress, address indexed to, uint indexed tokenId);
    event AdminWithdrawToken(address operator, address indexed tokenAddress, address indexed to, uint amount);
    event AdminWithdraw(address operator, address indexed to, uint amount);

    /**
     * @dev adminWithdrawNFT
     */
    function adminWithdrawNFT(address _token, address _to, uint _tokenId) external onlyAdmin returns (bool) {
        IERC721Upgradeable(_token).safeTransferFrom(address(this), _to, _tokenId);

        emit AdminWithdrawNFT(msg.sender, _token, _to, _tokenId);
        return true;
    }

    /**
     * @dev adminWithdrawToken
     */
    function adminWithdrawToken(address _token, address _to, uint _amount) external onlyAdmin returns (bool) {
        IERC20Upgradeable(_token).safeTransfer(_to, _amount);

        emit AdminWithdrawToken(msg.sender, _token, _to, _amount);
        return true;
    }

    /**
     * @dev adminWithdraw
     */
    function adminWithdraw(address payable _to, uint _amount) external onlyAdmin returns (bool) {
        _to.transfer(_amount);

        emit AdminWithdraw(msg.sender, _to, _amount);
        return true;
    }

}
