// SPDX-License-Identifier: MIT;

pragma solidity ^0.7.4;

abstract contract BSCPAD {
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    function setLaunchWhiteList(uint256 whiteListSeconds, address[] calldata whiteListAddresses, uint256[] calldata whiteListAmounts) external virtual;
    function totalSupply() external view virtual returns (uint256);
    function balanceOf(address account) external virtual view returns (uint256);
    function transfer(address recipient, uint256 amount) external virtual returns (bool);
    function approve(address spender, uint256 amount) external virtual returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external virtual returns (bool);
}
