pragma solidity 0.6.2;

import "./lib/ERC20Burnable.sol";
import "./lib/Ownable.sol";
import "./lib/VersionedInitializable.sol";

contract Coin is ERC20Burnable, Ownable, VersionedInitializable {
    function getRevision() internal override pure returns (uint256) {
        return uint256(0x1);
    }

    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address owner
    ) public initializer {
        initializeOwnable(owner);
        initializeERC20(name, symbol, decimals);
    }

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }
}
