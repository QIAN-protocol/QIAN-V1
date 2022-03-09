pragma solidity 0.6.2;

contract OracleMock {
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier auth() {
        require(
            msg.sender == owner,
            "mocks.feeder.auth/operation unauthorized"
        );
        _;
    }

    struct price_t {
        uint256 value;
        uint256 exp;
    }

    mapping(address => price_t) public prices;

    function getExpiration(address token) external view returns (uint256) {
        return prices[token].exp;
    }

    function getPrice(address token) public view returns (uint256) {
        return prices[token].value;
    }

    function get(address token) public view returns (uint256, bool) {
        return (prices[token].value, valid(token));
    }

    function valid(address token) public view returns (bool) {
        return now < prices[token].exp;
    }

    // 设置价格为 @val, 保持有效时间为 @exp second.
    function set(
        address token,
        uint256 value,
        uint256 exp
    ) external {
        prices[token] = price_t(value, now + exp);
    }

    //批量设置，减少gas使用
    function batchSet(
        address[] calldata tokens,
        uint256[] calldata values,
        uint256[] calldata exps
    ) external {
        uint256 nToken = tokens.length;
        require(
            nToken == values.length && values.length == exps.length,
            "invalid array length"
        );
        for (uint256 i = 0; i < nToken; ++i) {
            prices[tokens[i]] = price_t(values[i], now + exps[i]);
        }
    }
}
