pragma solidity 0.6.2;

interface IBurnable {
    function burn(address who, uint256 supply) external;
}