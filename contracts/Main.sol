pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";

import "./interfaces/IBalance.sol";
import "./interfaces/IEnv.sol";
import "./interfaces/IAsset.sol";
import "./interfaces/IPrice.sol";
import "./interfaces/IBurnable.sol";
import "./interfaces/IMintable.sol";
import "./interfaces/IBroker.sol";
import "./interfaces/IOrderbase.sol";
import "./interfaces/IFlashLoanReceiver.sol";

import "./lib/VersionedInitializable.sol";
import "./lib/ReentrancyGuard.sol";

contract Main is ReentrancyGuard, VersionedInitializable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event Deposit(
        address indexed sender,
        address indexed token,
        uint256 reserve,
        uint256 sysbalance
    );
    event Withdraw(
        address indexed sender,
        address indexed token,
        uint256 reserve,
        uint256 sysbalance
    );
    event Mint(
        address indexed sender,
        address indexed token,
        uint256 supply,
        uint256 coinsupply
    );
    event Burn(
        address indexed sender,
        address indexed token,
        uint256 supply,
        uint256 coinsupply
    );
    event Open(
        address indexed sender,
        address indexed token,
        uint256 reserve,
        uint256 supply,
        uint256 sysbalance,
        uint256 coinsupply
    );
    event Exchange(
        address indexed sender,
        uint256 supply,
        address indexed token,
        uint256 reserve,
        uint256 sysbalance,
        uint256 coinsupply,
        address[] frozens,
        uint256 price
    );

    event FlashLoan(
        address indexed receiver,
        address indexed token,
        uint256 amount,
        uint256 fee,
        uint256 time
    );

    address public env;
    address public balance;
    address public coin;
    address public asset;
    address public broker;
    address public orderbase;

    function initialize(
        address _env,
        address _balance,
        address _asset,
        address _coin,
        address _broker,
        address _orderbase
    ) public initializer {
        initializeReentrancyGuard();
        env = _env;
        balance = _balance;
        asset = _asset;
        coin = _coin;
        broker = _broker;
        orderbase = _orderbase;
    }

    function getRevision() internal override pure returns (uint256) {
        return uint256(0x1);
    }

    function deposit(address token, uint256 reserve)
        public
        payable
        nonReentrant
    {
        uint256 _reserve = _deposit(token, reserve);
        IBroker(broker).publish(keccak256("deposit"), abi.encode(msg.sender, token, _reserve));
        IOrderbase(orderbase).insert(msg.sender, token);
        emit Deposit(
            msg.sender,
            token,
            _reserve,
            IAsset(asset).balances(token)
        );
    }

    function withdraw(address token, uint256 reserve) public nonReentrant {
        _withdraw(token, reserve);
        require(ade(msg.sender, token) >= IEnv(env).aade(token), "Main.withdraw.EID00063");
        IBroker(broker).publish(keccak256("withdraw"), abi.encode(msg.sender, token, reserve));
        emit Withdraw(
            msg.sender,
            token,
            reserve,
            IAsset(asset).balances(token)
        );
    }

    //增发
    function mint(address token, uint256 supply) public nonReentrant {
        _mint(token, supply);
        IBroker(broker).publish(keccak256("mint"), abi.encode(msg.sender, token, supply));
        emit Mint(msg.sender, token, supply, IERC20(coin).totalSupply());
    }

    //销毁
    function burn(address token, uint256 supply) public nonReentrant {
        _burn(token, supply);
        IBroker(broker).publish(keccak256("burn"), abi.encode(msg.sender, token, supply));
        emit Burn(msg.sender, token, supply, IERC20(coin).totalSupply());
    }

    //开仓
    function open(
        address token, //deposit token
        uint256 reserve,
        uint256 supply
    ) public payable nonReentrant {
        uint256 _reserve = _deposit(token, reserve);
        _mint(token, supply);
        IBroker(broker).publish(keccak256("open"), abi.encode(msg.sender, token, _reserve, supply));
        IOrderbase(orderbase).insert(msg.sender, token);
        emit Open(
            msg.sender,
            token,
            _reserve,
            supply,
            IAsset(asset).balances(token),
            IERC20(coin).totalSupply()
        );
    }

    //清算
    function exchange(
        uint256 supply, //QIAN
        address token,
        address[] memory frozens
    ) public nonReentrant {
        require(!IEnv(env).lockdown(), "Main.exchange.EID00030");
        require(supply != 0, "Main.exchange.EID00090");
        address[] memory _frozens = _refreshfrozens(token, frozens);
        require(_frozens.length != 0, "Main.exchange.EID00091");

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
            //fix: Stack too deep, try removing local variables.
            (address _owner, address _token) = (_frozens[i], token);

            uint256 rid = Math.min(swaps[i].supply, _supply);
            _supply = _supply.sub(rid);

            uint256 lot = rid.mul(swaps[i].reserve).div(swaps[i].supply);
            lot = Math.min(lot, swaps[i].reserve);

            IBalance(balance).exchange(msg.sender, _owner, _token, rid, lot);
            IBroker(broker).publish(keccak256("burn"), abi.encode(_owner, _token, rid));
            reserve = reserve.add(lot);
            if (_supply == 0) break;
        }

        uint256 __supply = supply.sub(_supply);
        IBurnable(coin).burn(msg.sender, __supply);
        _withdraw(token, reserve);
        IBroker(broker).publish(keccak256("exchange"), abi.encode(msg.sender, __supply, token, reserve, _frozens));
        emit Exchange(
            msg.sender,
            __supply,
            token,
            reserve,
            IAsset(asset).balances(token),
            IERC20(coin).totalSupply(),
            _frozens,
            _price(token)
        );
    }

    function flashloan(
        address receiver,
        address token,
        uint256 amount,
        bytes memory params
    ) public nonReentrant {
        require(!IEnv(env).lockdown(), "Main.flashloan.EID00030");
        require(
            IEnv(env).hasToken(token) && !IEnv(env).deprecatedTokens(token),
            "Main.flashloan.EID00070"
        );

        require(amount > 0, "Main.flashloan.EID00090");
        uint256 balancesBefore = IAsset(asset).balances(token);
        require(balancesBefore >= amount, "Main.flashlon.EID00100");

        uint256 flashloanRate = IEnv(env).flashloanRate();
        uint256 fee = amount.mul(flashloanRate).div(10000);
        require(fee > 0, "Main.flashloan.EID00101");

        IFlashLoanReceiver flashLoanReceiver = IFlashLoanReceiver(receiver);
        address payable _receiver = address(uint160(receiver));

        IAsset(asset).withdraw(_receiver, token, amount);
        flashLoanReceiver.execute(token, amount, fee, asset, params);

        uint256 balancesAfter = IAsset(asset).balances(token);
        require(balancesAfter == balancesBefore.add(fee), "Main.flashloan.EID00102");

        IAsset(asset).withdraw(IEnv(env).protocolAsset(), token, fee);
        emit FlashLoan(receiver, token, amount, fee, block.timestamp);
    }

    //充足率 (Adequacy ratio)

    //@who @token 对应的资产充足率
    function ade(address owner, address token) public view returns (uint256) {
        IBalance.swap_t memory swap = IBalance(balance).swaps(owner, token);
        if (swap.supply == 0) return uint256(-1);

        //uint256 coinprice = 1e18; (每"个"QIAN的价格)
        //(swap.reserve / 10**_dec(token)) * _price(token)
        //uint256 reservevalue = swap.reserve.mul(_price(token)).div(10**_dec(token));  //1e18
        //(swap.supply / 10**_dec(coin)) * coinprice;
        //uint256 coinvalue = swap.supply.mul(coinprice).div(10**_dec(coin)) //1e18
        //ade = (reservevalue/coinvalue) * 1e18 (充足率的表示单位)
        //uint256 ade = swap.reserve.mul(_price(token)).div(10**_dec(token)).mul(1e18).div(swap.supply.mul(1e18).div(10**_dec(coin)))
        //            = swap.reserve.mul(_price(token)).mul(1e18).div(10**_dec(token)).div(swap.supply.mul(1e18).div(10**_dec(coin)))
        //            = swap.reserve.mul(_price(token)).mul(10**_dec(coin)).div(10**_dec(token)).div(swap.supply)

        return
            swap
                .reserve
                .mul(_price(token))
                .mul(10**_dec(coin))
                .div(10**_dec(token))
                .div(swap.supply);
    }

    //@token 对应的资产充足率
    function ade(address token) public view returns (uint256) {
        IBalance.swap_t memory gswap = IBalance(balance).gswaps(token);
        if (gswap.supply == 0) return uint256(-1);
        return
            gswap
                .reserve
                .mul(_price(token))
                .mul(10**_dec(coin))
                .div(10**_dec(token))
                .div(gswap.supply);
    }

    //系统总资产充足率
    function ade() public view returns (uint256) {
        uint256 reserve_values = 0;
        address[] memory tokens = IEnv(env).tokens();
        for (uint256 i = 0; i < tokens.length; ++i) {
            reserve_values = reserve_values.add(
                IBalance(balance).reserve(tokens[i]).mul(_price(tokens[i])).div(
                    10**_dec(tokens[i])
                )
            );
        }
        uint256 gsupply_values = IBalance(balance).gsupply();
        if (gsupply_values == 0) return uint256(-1);
        return reserve_values.mul(10**_dec(coin)).div(gsupply_values);
    }

    /** innernal functions */

    function _burn(address token, uint256 supply) internal {
        //全局停机
        require(!IEnv(env).lockdown(), "Main.burn.EID00030");
        //被废弃的代币生成的QIAN仍然允许销毁.
        require(IEnv(env).hasToken(token), "Main.burn.EID00070");
        uint256 _supply = IBalance(balance).supply(msg.sender, token);
        require(_supply >= supply, "Main.burn.EID00080");
        IBurnable(coin).burn(msg.sender, supply);
        IBalance(balance).burn(msg.sender, token, supply);
    }

    function _deposit(address token, uint256 reserve) internal returns(uint256) {
        require(!IEnv(env).lockdown(), "Main.deposit.EID00030");
        //仅当受支持的代币才允许增加准备金(被废弃的代币不允许)
        require(IEnv(env).hasToken(token) && !IEnv(env).deprecatedTokens(token), "Main.deposit.EID00070");
        uint256 _reserve = IAsset(asset).deposit.value(msg.value)(
            msg.sender,
            token,
            reserve
        );
        IBalance(balance).deposit(msg.sender, token, _reserve);
        return _reserve;
    }

    function _mint(address token, uint256 supply) internal {
        require(!IEnv(env).lockdown(), "Main.mint.EID00030");
        require(IEnv(env).hasToken(token) && !IEnv(env).deprecatedTokens(token), "Main.mint.EID00071");

        uint256 _step = IEnv(env).step();
        require(supply >= _step, "Main.mint.EID00092");

        IMintable(coin).mint(msg.sender, supply);
        IBalance(balance).mint(msg.sender, token, supply);

        //后置充足率检测.
        require(ade(msg.sender, token) >= IEnv(env).bade(token), "Main.mint.EID00062");

        uint256 _supply = IBalance(balance).supply(token);
        uint256 _line = IEnv(env).line(token);
        require(_supply <= _line, "Main.mint.EID00093");
    }

    function _withdraw(address token, uint256 reserve) internal {
        require(!IEnv(env).lockdown(), "Main.withdraw.EID00030");
        require(IEnv(env).hasToken(token), "Main.withdraw.EID00070");
        uint256 _reserve = IBalance(balance).reserve(msg.sender, token);
        require(_reserve >= reserve, "Main.withdraw.EID00081");
        IBalance(balance).withdraw(msg.sender, token, reserve);
        IAsset(asset).withdraw(msg.sender, token, reserve);
        //充足率检测在外部调用处进行.
    }

    function _price(address token) internal view returns (uint256) {
        (uint256 value, bool valid) = IPrice(IEnv(env).oracle()).value(
            token
        );
        require(valid, "Main.price.EID00094");
        return value;
    }

    //仓位是否被冻结.
    function _isfade(address owner, address token)
        internal
        view
        returns (bool)
    {
        return ade(owner, token) < IEnv(env).fade(token);
    }

    //从@frozens过滤已经不再是冻结状态的仓位
    function _refreshfrozens(address token, address[] memory frozens)
        internal
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

    function _dec(address token) public view returns (uint256) {
        return IAsset(asset).decimals(token);
    }
}
