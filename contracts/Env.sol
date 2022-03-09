pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./lib/VersionedInitializable.sol";
import "./lib/Administered.sol";

contract Env is Administered, VersionedInitializable {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Tokenargs {
        uint256 bade; //初始资产充足率      //Basic Adequacy ratio
        uint256 aade; //预警资产充足率      //Alarm Adequacy ratio
        uint256 fade; //最低资产充足率      //Frozen Adequacy ratio
        uint256 line; //最高铸币量
    }

    uint256 public step; //单次最低铸币量(所有币种)
    uint256 public gade; //全局充足率 //global adequacy ratio
    mapping(address => Tokenargs) public tokenargs;

    address public gtoken; //治理代币
    address public oracle; //价格预言机
    EnumerableSet.AddressSet private _tokens; //支持的币种列表
    mapping(address => bool) public deprecatedTokens; //被废弃的币种列表, 只出不进
    bool public lockdown;

    uint256 public flashloanRate;
    address public protocolAsset;

    bytes32 public constant LOCKDOWN_ROLE = keccak256("LOCKDOWN");
    bytes32 public constant ACTIVE_ROLE = keccak256("ACTIVE");

    function getRevision() internal override pure returns (uint256) {
        return uint256(0x1);
    }

    function initialize(address owner) public initializer {
        initializeAdministered(owner);
        _setRoleAdmin(LOCKDOWN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ACTIVE_ROLE, DEFAULT_ADMIN_ROLE);
    }

    modifier onlyLockdown {
        require(hasRole(LOCKDOWN_ROLE, msg.sender), "Restricted to lockdown");
        _;
    }

    modifier onlyActive {
        require(hasRole(ACTIVE_ROLE, msg.sender), "Restricted to active");
        _;
    }

    function bade(address token) external view returns (uint256) {
        return tokenargs[token].bade;
    }

    function aade(address token) external view returns (uint256) {
        return tokenargs[token].aade;
    }

    function fade(address token) external view returns (uint256) {
        return tokenargs[token].fade;
    }

    function line(address token) external view returns (uint256) {
        return tokenargs[token].line;
    }

    function setStep(uint256 _step) public onlyActive {
        step = _step;
    }

    function setOracle(address _oracle) public onlyActive {
        oracle = _oracle;
    }

    function setGtoken(address _gtoken) public onlyActive {
        gtoken = _gtoken;
    }

    //批量设置充足率
    //@nades: 被设置的数量.
    //@ades: 被设置的信息([].push(abi.encode(token, bade, aade, face)))
    function setAdes(bytes[] memory ades) public onlyActive {
        uint256 _length = ades.length;
        for (uint256 i = 0; i < _length; ++i) {
            (address _token, uint256 _bade, uint256 _aade, uint256 _fade) = abi
                .decode(ades[i], (address, uint256, uint256, uint256));
            tokenargs[_token].bade = _bade;
            tokenargs[_token].aade = _aade;
            tokenargs[_token].fade = _fade;
            require(hasToken(_token), "Environment.setAdes.EID00070");
            require(_bade > _aade, "Environment.setAdes.EID00098");
            require(_aade > _fade, "Environment.setAdes.EID00098");
        }
    }

    function setLine(address token, uint256 _line) public onlyActive {
        require(hasToken(token), "Environment.setLine.EID00070");
        tokenargs[token].line = _line;
    }

    function setGade(uint256 _gade) public onlyActive {
        gade = _gade;
    }

    function addToken(address token) public onlyActive {
        require(
            _tokens.add(token) || deprecatedTokens[token],
            "env.addtoken.EID00015"
        );
        deprecatedTokens[token] = false;
    }

    function deprecateToken(address token) public onlyActive {
        require(_tokens.contains(token), "env.deprecatetoken.EID00016");
        deprecatedTokens[token] = true;
    }

    function removeToken(address token) public onlyActive {
        require(_tokens.remove(token), "env.removetoken.EID00016");
        deprecatedTokens[token] = false;
    }

    //global lock
    function glock() public onlyLockdown {
        lockdown = true;
    }

    //global unlock
    function gunlock() public onlyLockdown {
        lockdown = false;
    }

    function hasToken(address token) public view returns (bool) {
        return _tokens.contains(token);
    }

    function tokens() external view returns (address[] memory) {
        address[] memory values = new address[](_tokens.length());
        for (uint256 i = 0; i < _tokens.length(); ++i) {
            values[i] = _tokens.at(i);
        }
        return values;
    }

    function setFlashloanRate(uint256 _flashloanRate) public onlyActive {
        flashloanRate = _flashloanRate;
    }

    function setProtocolAsset(address _protocolAsset) public onlyActive {
        protocolAsset = _protocolAsset;
    }
}
