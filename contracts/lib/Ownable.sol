pragma solidity ^0.6.0;

contract Ownable {
    /** events */

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /** member */

    address public owner;

    /** constructor */

    function initializeOwnable(address _owner) internal {
        owner = _owner;
    }

    /** modifers */

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable.onlyOwner.EID00001");
        _;
    }

    /** functions */
    
    function transferOwnership(address _owner) public onlyOwner {
        require(_owner != address(0), "Ownable.transferOwnership.EID00090");
        emit OwnershipTransferred(owner, _owner);
        owner = _owner;
    }
}
