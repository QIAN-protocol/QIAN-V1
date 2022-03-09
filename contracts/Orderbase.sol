pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;

import "./lib/VersionedInitializable.sol";
import "./lib/Ownable.sol";

contract Orderbase is Ownable, VersionedInitializable {
    event Insert(address indexed owner, address indexed token, uint256 id);

    struct hold_t {
        address owner;
        address token;
    }
    uint256 public size;
    //id => hold_t
    mapping(uint256 => hold_t) private _holds; //@_indexes start with 1
    //owner => token => id;
    mapping(address => mapping(address => uint256)) private _indexes;
    //token => owners
    mapping(address => address[]) private _owners;
    //owner => tokens
    mapping(address => address[]) private _tokens;

    function getRevision() internal override pure returns (uint256) {
        return uint256(0x1);
    }

    function initialize(address owner) public initializer {
        Ownable.initializeOwnable(owner);
    }

    function insert(address _owner, address _token) public returns (uint256) {
        uint256 _id = _indexes[_owner][_token];
        if (_id == 0) {
            ++size;
            _holds[size] = hold_t(_owner, _token);
            _indexes[_owner][_token] = size;
            _owners[_token].push(_owner);
            _tokens[_owner].push(_token);
            emit Insert(_owner, _token, size);
            return size;
        }
        return _id;
    }
    
    function holder(uint256 id) public view returns (address, address) {
        return (_holds[id].owner, _holds[id].token);
    }

    //csa-index
    function index(address _owner, address _token) public view returns (uint256) {
        return _indexes[_owner][_token];
    }

    function owners(
        address token,
        uint256 begin, //@begin start with 0
        uint256 end
    ) public view returns (address[] memory) {
        address[] memory sources = _owners[token];
        address[] memory values;
        (uint256 _begin, uint256 _end) = (begin, end);

        if (begin >= end) return values;
        if (begin >= sources.length) return values;
        if (_end > sources.length) {
            _end = sources.length;
        }

        values = new address[](_end - begin);
        uint256 i = 0;
        for (; _begin != _end; ++_begin) {
            values[i++] = sources[_begin];
        }
        return values;
    }

    function owners(address _token) public view returns (address[] memory) {
        return _owners[_token];
    }

    function tokens(address _owner) public view returns (address[] memory) {
        return _tokens[_owner];
    }
}
