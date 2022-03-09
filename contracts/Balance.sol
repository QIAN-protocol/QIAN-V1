pragma solidity 0.6.2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./lib/VersionedInitializable.sol";
import "./lib/Ownable.sol";

contract Balance is Ownable, VersionedInitializable {
    using SafeMath for uint256;

    struct swap_t {
        uint256 reserve;
        uint256 supply;
        uint256 __reserved__field_0;
        uint256 __reserved__field_1;
        uint256 __reserved__field_2;
        uint256 __reserved__field_3;
    }

    mapping(address => mapping(address => swap_t)) public swaps; //user->token->swap_t
    mapping(address => swap_t) public gswaps; //token-> swap_t
    uint256 public gsupply;

    function getRevision() internal override pure returns (uint256) {
        return uint256(0x1);
    }

    function initialize(address owner) public initializer {
        Ownable.initializeOwnable(owner);
    }

    function deposit(
        address payer,
        address token,
        uint256 reserve
    ) public onlyOwner {
        swaps[payer][token].reserve = swaps[payer][token].reserve.add(reserve);
        gswaps[token].reserve = gswaps[token].reserve.add(reserve);
    }

    function withdraw(
        address receiver,
        address token,
        uint256 reserve
    ) public onlyOwner {
        swaps[receiver][token].reserve = swaps[receiver][token].reserve.sub(
            reserve
        );
        gswaps[token].reserve = gswaps[token].reserve.sub(reserve);
    }

    function burn(
        address payer,
        address token,
        uint256 supply
    ) public onlyOwner {
        swaps[payer][token].supply = swaps[payer][token].supply.sub(supply);
        gswaps[token].supply = gswaps[token].supply.sub(supply);
        gsupply = gsupply.sub(supply);
    }

    function mint(
        address receiver,
        address token,
        uint256 supply
    ) public onlyOwner {
        swaps[receiver][token].supply = swaps[receiver][token].supply.add(
            supply
        );
        gswaps[token].supply = gswaps[token].supply.add(supply);
        gsupply = gsupply.add(supply);
    }

    //销毁 @payer 的 QIAN, 并且增加相应的 @reserve 记录给 @payer, 同时 @who 减少相应的记录.
    function exchange(
        address payer,
        address owner,
        address token,
        uint256 supply,
        uint256 reserve
    ) public onlyOwner {
        swaps[owner][token].supply = swaps[owner][token].supply.sub(supply);
        gswaps[token].supply = gswaps[token].supply.sub(supply);
        gsupply = gsupply.sub(supply);
        swaps[owner][token].reserve = swaps[owner][token].reserve.sub(reserve);
        swaps[payer][token].reserve = swaps[payer][token].reserve.add(reserve);
    }

    function reserve(address who, address token)
        external
        view
        returns (uint256)
    {
        return swaps[who][token].reserve;
    }

    function supply(address who, address token)
        external
        view
        returns (uint256)
    {
        return swaps[who][token].supply;
    }

    function reserve(address token) external view returns (uint256) {
        return gswaps[token].reserve;
    }

    function supply(address token) public view returns (uint256) {
        return gswaps[token].supply;
    }
}
