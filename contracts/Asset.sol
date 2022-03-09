pragma solidity 0.6.2;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IERC20Detailed.sol";

import "./lib/VersionedInitializable.sol";
import "./lib/Ownable.sol";

contract Asset is Ownable, VersionedInitializable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Address for address payable;

    receive() external payable {
        require(msg.sender.isContract(), "Only contracts can send ether");
    }

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
    ) public payable onlyOwner returns (uint256) {
        if (token == address(0)) {
            require(msg.value == reserve, "Asset.deposit.EID00095");
            return reserve;
        } else {
            require(msg.value == 0, "Asset.deposit.EID00096");
            uint256 _balanceOfthis = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransferFrom(payer, address(this), reserve);
            return IERC20(token).balanceOf(address(this)).sub(_balanceOfthis);
        }
    }

    function withdraw(
        address payable receiver,
        address token,
        uint256 reserve
    ) public onlyOwner returns (uint256) {
        if (token == address(0)) {
            receiver.transfer(reserve);
        } else {
            IERC20(token).safeTransfer(receiver, reserve);
        }
        return reserve;
    }

    function balances(address token) public view returns (uint256) {
        if (token == address(0)) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }

    function decimals(address token) public view returns (uint256) {
        if (token == address(0)) {
            return 18;
        }
        return IERC20Detailed(token).decimals();
    }
}
