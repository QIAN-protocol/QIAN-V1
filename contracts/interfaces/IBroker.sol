pragma solidity 0.6.2;

interface IBroker {
    function publish(bytes32 topic, bytes calldata data) external;
}
