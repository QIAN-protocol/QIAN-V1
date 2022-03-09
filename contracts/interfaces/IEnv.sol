pragma solidity 0.6.2;

interface IEnv {
    function bade(address token) external view returns (uint256);
    function aade(address token) external view returns (uint256);
    function fade(address token) external view returns (uint256);
    function gade() external view returns(uint256);
    function line(address token) external view returns (uint256);
    function step() external view returns (uint256);
    function oracle() external view returns (address);
    function tokens() external view returns (address[] memory);
    function gtoken() external view returns (address);
    function hasToken(address token) external view returns(bool);
    function deprecatedTokens(address token) external view returns(bool);
    function lockdown() external view returns(bool);
    function flashloanRate() external view returns(uint256);
    function protocolAsset() external view returns(address payable);
}
