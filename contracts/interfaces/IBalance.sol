pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;

interface IBalance {
    struct swap_t {
        uint256 reserve; //抵押token
        uint256 supply; //QIAN
    }

    function withdraw(
        address receiver,
        address token,
        uint256 reserve
    ) external;

    function deposit(
        address payer,
        address token,
        uint256 reserve
    ) external payable;

    function burn(
        address payer,
        address token,
        uint256 supply
    ) external;

    function mint(
        address receiver,
        address token,
        uint256 supply
    ) external;

    function exchange(
        address payer,
        address owner,
        address token,
        uint256 supply,
        uint256 reserve
    ) external;

    function reserve(address who, address token)
        external
        view
        returns (uint256);

    function supply(address who, address token) external view returns (uint256);

    function reserve(address token) external view returns (uint256);

    function supply(address token) external view returns (uint256);

    function swaps(address who, address token)
        external
        view
        returns (swap_t memory);

    function gswaps(address token) external view returns (swap_t memory);

    function gsupply() external view returns (uint256);
}
