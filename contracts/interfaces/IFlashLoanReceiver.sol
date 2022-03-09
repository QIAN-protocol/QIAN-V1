pragma solidity ^0.6.2;

interface IFlashLoanReceiver {
    function execute(address token, uint256 amount, uint256 fee, address back, bytes calldata params) external;
}