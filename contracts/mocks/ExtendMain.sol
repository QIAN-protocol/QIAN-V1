pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";

import "../interfaces/IBalance.sol";
import "../interfaces/IEnv.sol";
import "../interfaces/IOrderbase.sol";
import "../interfaces/IAsset.sol";
import "../interfaces/IERC20Detailed.sol";
import "../interfaces/IPrice.sol";

interface IMain {
    function env() external returns (address);

    function balance() external returns (address);

    function coin() external returns (address);

    function asset() external returns (address);

    function broker() external returns (address);

    function orderbase() external returns (address);

    function ade(address owner, address token) external view returns (uint256);

    function ade(address token) external view returns (uint256);

    function ade() external view returns (uint256);
}

contract ExtendMain {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public main;

    address public env;
    address public balance;
    address public coin;
    address public asset;
    address public broker;
    address public orderbase;

    constructor(address _main) public {
        main = _main;

        env = IMain(main).env();
        balance = IMain(main).balance();
        coin = IMain(main).coin();
        asset = IMain(main).asset();
        broker = IMain(main).broker();
        orderbase = IMain(main).orderbase();
    }

    //累计所有冻结仓位的债务总量 SUM(swap.supply)
    function frozensupplies(address token, address[] memory frozens)
        public
        view
        returns (uint256)
    {
        address[] memory _frozens = refreshfrozens(token, frozens);
        uint256 supplies = 0;
        for (uint256 i = 0; i < _frozens.length; ++i) {
            supplies = supplies.add(
                IBalance(balance).supply(_frozens[i], token)
            );
        }
        return supplies;
    }

    //累计所有冻结仓位的抵押物总量 SUM(swap.reserve)
    function frozenreserves(address token, address[] memory frozens)
        public
        view
        returns (uint256)
    {
        address[] memory _frozens = refreshfrozens(token, frozens);
        uint256 reserves = 0;
        for (uint256 i = 0; i < _frozens.length; ++i) {
            reserves = reserves.add(
                IBalance(balance).reserve(_frozens[i], token)
            );
        }
        return reserves;
    }

    //获取@supply可以从冻结仓位中兑换的资产数量.
    function frozenvalues(
        uint256 supply, //QIAN
        address token,
        address[] memory frozens
    ) public view returns (uint256, uint256) {
        if (supply == 0) return (0, 0);
        address[] memory _frozens = refreshfrozens(token, frozens);
        if (_frozens.length == 0) return (0, 0);

        //fix: 缓存被冻结仓位的状态, 当兑换人自己的仓位也属于冻结仓位时, 避免由于其他仓位数据划转(到兑换人的仓位)而导致兑换人自己的仓位数据发生变化
        IBalance.swap_t[] memory swaps = new IBalance.swap_t[](_frozens.length);
        for (uint256 i = 0; i < _frozens.length; ++i) {
            //fix: Stack too deep, try removing local variables.
            (address _owner, address _token) = (_frozens[i], token);
            swaps[i] = IBalance(balance).swaps(_owner, _token);
        }

        uint256 _supply = supply;
        uint256 reserve = 0;
        for (uint256 i = 0; i < _frozens.length; ++i) {
            uint256 rid = Math.min(swaps[i].supply, _supply);
            _supply = _supply.sub(rid);

            uint256 lot = rid.mul(swaps[i].reserve).div(swaps[i].supply);
            lot = Math.min(lot, swaps[i].reserve);

            reserve = reserve.add(lot);

            if (_supply == 0) break;
        }

        return (supply.sub(_supply), reserve);
    }

    //累计所有冻结仓位的抵押物数量和价值
    function frozenvalues(address token, address[] memory frozens)
        public
        view
        returns (uint256, uint256)
    {
        uint256 reserves = frozenreserves(token, frozens);
        return (reserves.mul(price(token)).div(1e18), reserves);
    }

    //所有冻结仓位的平均充足率
    function frozenade(address token, address[] memory frozens)
        public
        view
        returns (uint256)
    {
        address[] memory _frozens = refreshfrozens(token, frozens);
        (uint256 supplies, uint256 reserves) = (0, 0);
        for (uint256 i = 0; i < _frozens.length; ++i) {
            IBalance.swap_t memory swap = IBalance(balance).swaps(
                _frozens[i],
                token
            );
            supplies = supplies.add(swap.supply);
            reserves = reserves.add(swap.reserve);
        }

        return
            reserves
                .mul(price(token))
                .mul(10**_dec(coin))
                .div(10**_dec(token))
                .div(supplies);
    }

    //从@frozens过滤已经不再是冻结状态的仓位
    function refreshfrozens(address token, address[] memory frozens)
        public
        view
        returns (address[] memory)
    {
        uint256 n = 0;
        for (uint256 i = 0; i < frozens.length; ++i) {
            if (_isfade(frozens[i], token)) {
                frozens[n++] = frozens[i];
            }
        }
        address[] memory _frozens = new address[](n);
        for (uint256 i = 0; i < n; ++i) {
            _frozens[i] = frozens[i];
        }
        return _frozens;
    }

    //被冻结的CSA持有者地址列表.
    function frozens(address token) public view returns (address[] memory) {
        uint256 n = 0;
        address[] memory owners = IOrderbase(orderbase).owners(
            token,
            0,
            IOrderbase(orderbase).size()
        );
        for (uint256 i = 0; i < owners.length; ++i) {
            if (_isfade(owners[i], token)) {
                owners[n++] = owners[i];
            }
        }
        address[] memory _frozens = new address[](n);
        for (uint256 i = 0; i < n; ++i) {
            _frozens[i] = owners[i];
        }
        return _frozens;
    }

    function gainable(address token, uint256 supply)
        public
        view
        returns (uint256)
    {
        return
            supply.mul(10**(_dec(token).add(18).sub(_dec(coin)))).div(
                price(token)
            );
    }

    //代币价格
    function price(address token) public view returns (uint256) {
        (uint256 value, bool valid) = IPrice(IEnv(env).oracle()).value(token);
        require(valid, "Utils.price/invalid price value");
        return value;
    }

    ///helpers

    //仓位最大可取回数量
    function withdrawable(address who, address token)
        public
        view
        returns (uint256)
    {
        IBalance.swap_t memory swap = IBalance(balance).swaps(who, token);

        //uint256 coinprice = 1e18;
        //uint256 value = (coinprice / 10 ** _dec(coin)) * swap.supply * (1.2 * 1e18) / 1e18;
        //uint256 reserve = value / (tokenprice / 10 ** _dec(token));
        //return swap.reserve - reserve;

        uint256 locked = swap
            .supply
            .mul(IEnv(env).fade(token))
            .mul(10**_dec(token))
            .div(10**_dec(coin))
            .div(price(token));
        return swap.reserve.sub(Math.min(locked, swap.reserve));
    }

    //仓位最大可增发数量
    function mintable(address who, address token)
        public
        view
        returns (uint256)
    {
        IBalance.swap_t memory swap = IBalance(balance).swaps(who, token);
        uint256 supply = swap
            .reserve
            .mul(price(token))
            .mul(10**_dec(coin))
            .div(10**_dec(token))
            .div(IEnv(env).bade(token));
        return supply.sub(Math.min(supply, swap.supply));
    }

    //仓位最大可销毁数量
    function burnable(address who, address token)
        public
        view
        returns (uint256)
    {
        return IBalance(balance).supply(who, token);
    }

    function swaps(address who, address token)
        public
        view
        returns (uint256, uint256)
    {
        IBalance.swap_t memory swap = IBalance(balance).swaps(who, token);
        return (swap.reserve, swap.supply);
    }

    function openable(address token, uint256 reserve)
        public
        view
        returns (uint256)
    {
        return
            reserve
                .mul(price(token))
                .mul(10**_dec(coin))
                .div(10**_dec(token))
                .div(IEnv(env).bade(token));
    }

    //仓位是否满足初始充足率
    function _isbade(address owner, address token)
        internal
        view
        returns (bool)
    {
        return IMain(main).ade(owner, token) >= IEnv(env).bade(token);
    }

    //仓位是否被冻结.
    function _isfade(address owner, address token)
        internal
        view
        returns (bool)
    {
        return IMain(main).ade(owner, token) < IEnv(env).fade(token);
    }

    function _dec(address token) public view returns (uint256) {
        return IAsset(asset).decimals(token);
    }
}
