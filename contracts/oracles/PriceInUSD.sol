pragma solidity 0.6.2;

import "../interfaces/IOracle.sol";

contract PriceInUSD {
    address public oracle;
    
    constructor(address _oracle) public {
        oracle = _oracle;
    }

    function value(address token) public view returns (uint256, bool) {
        return IOracle(oracle).get(token);
    }
}
