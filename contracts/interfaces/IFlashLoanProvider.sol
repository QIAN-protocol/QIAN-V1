pragma solidity ^0.6.2;

interface IFlashLoanProvider {
    function flashloan(address receiver, address token, uint256 amount, bytes calldata params) external;
}