pragma solidity 0.6.2;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract Administered is AccessControl {
    /// @dev Add `root` to the admin role as a member.
    function initializeAdministered(address admin) internal {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @dev Restricted to members of the admin role.
    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "Restricted to admins.");
        _;
    }

    /// @dev Return `true` if the account belongs to the admin role.
    function isAdmin(address account) public virtual view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    /// @dev Add an account to the user role. Restricted to admins.
    function addAccount(bytes32 role, address account)
        public
        virtual
        onlyAdmin
    {
        grantRole(role, account);
    }

    /// @dev Remove an account from the user role. Restricted to admins.
    function removeAccount(bytes32 role, address account)
        public
        virtual
        onlyAdmin
    {
        revokeRole(role, account);
    }

    /// @dev Add an account to the admin role. Restricted to admins.
    function addAdmin(address account) public virtual onlyAdmin {
        grantRole(DEFAULT_ADMIN_ROLE, account);
    }

    /// @dev Remove oneself from the admin role.
    function renounceAdmin() public virtual {
        renounceRole(DEFAULT_ADMIN_ROLE, msg.sender);
        require(getRoleMemberCount(DEFAULT_ADMIN_ROLE) >= 1, "At least one admin required");
    }
}
