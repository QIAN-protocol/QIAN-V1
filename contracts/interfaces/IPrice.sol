pragma solidity 0.6.2;

interface IPrice {
    function value(address token) external view returns (uint256, bool);
}
