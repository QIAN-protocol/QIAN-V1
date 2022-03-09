pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;

interface IOrderbase {
    function holder(uint256 index) external view returns (address, address);
    function index(address owner, address token) external view returns (uint256);
    function owners(address token, uint256 begin, uint256 end) external view returns (address[] memory);
    function owners(address token) external view returns (address[] memory);
    function tokens(address owner) external view returns (address[] memory);
    function size() external view returns (uint256);
    function insert(address owner, address token) external returns (uint256);
}
