pragma solidity 0.6.2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./lib/VersionedInitializable.sol";
import "./lib/Administered.sol";

contract Broker is Administered, VersionedInitializable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant PLUGINMGR_ROLE = keccak256("PLUGINMGR");
    bytes32 public constant PUBLISHER_ROLE = keccak256("PUBLISHER");

    function initialize(address owner) public initializer {
        initializeAdministered(owner);
        _setRoleAdmin(PLUGINMGR_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(PUBLISHER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    function getRevision() internal override pure returns (uint256) {
        return uint256(0x1);
    }

    modifier onlyPublisher {
        require(hasRole(PUBLISHER_ROLE, msg.sender), "Restricted to publisher");
        _;
    }

    modifier onlyPluginmgr {
        require(hasRole(PLUGINMGR_ROLE, msg.sender), "Restricted to pluginmgr");
        _;
    }

    //publisher => topic => subscriber
    mapping(address => mapping(bytes32 => EnumerableSet.AddressSet))
        private _subscribers;
    //subscriber => publisher => topic => handler
    mapping(address => mapping(address => mapping(bytes32 => bytes4)))
        public handlers;

    function subscribe(
        address subscriber, //订阅者
        address publisher, //发布者
        bytes32 topic, //被订阅的消息
        bytes4 handler //消息处理函数
    ) public onlyPluginmgr {
        require(
            handlers[subscriber][publisher][topic] != handler,
            "Broker.subscribe.EID00015"
        );
        _subscribers[publisher][topic].add(subscriber);
        handlers[subscriber][publisher][topic] = handler;
    }

    function unsubscribe(
        address subscriber,
        address publisher,
        bytes32 topic
    ) public onlyPluginmgr {
        require(
            handlers[subscriber][publisher][topic] != bytes4(0),
            "Broker.unsubscribe.EID00016"
        );
        _subscribers[publisher][topic].remove(subscriber);
        delete handlers[subscriber][publisher][topic];
    }

    //sig: handler(address publiser, bytes32 topic, bytes memory data)
    function publish(bytes32 topic, bytes calldata data)
        external
        onlyPublisher
    {
        uint256 length = _subscribers[msg.sender][topic].length();
        for (uint256 i = 0; i < length; ++i) {
            address subscriber = _subscribers[msg.sender][topic].at(i);
            bytes memory _data = abi.encodeWithSelector(
                handlers[subscriber][msg.sender][topic],
                msg.sender,
                topic,
                data
            );
            (bool successed, ) = subscriber.call(_data);
            require(successed, "Broker.publish.EID00020");
        }
    }

    function subscribers(address publisher, bytes32 topic)
        external
        view
        returns (address[] memory)
    {
        address[] memory values = new address[](
            _subscribers[publisher][topic].length()
        );
        for (uint256 i = 0; i < values.length; ++i) {
            values[i] = _subscribers[publisher][topic].at(i);
        }
        return values;
    }
}
