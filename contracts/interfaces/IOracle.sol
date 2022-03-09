pragma solidity 0.6.2;

interface IOracle {
    function getExpiration(address token) external view returns (uint256);

    function getPrice(address token) external view returns (uint256);

    function get(address token) external view returns (uint256, bool);

    function valid(address token) external view returns (bool);

    function set(
        address token,
        uint256 val,
        uint256 exp
    ) external;

    function batchSet(
        address[] calldata tokens,
        uint256[] calldata vals,
        uint256[] calldata exps
    ) external;
}
