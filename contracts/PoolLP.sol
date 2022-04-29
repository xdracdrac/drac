// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./common/AdminBaseUpgradeable.sol";
import "./config/ConfigBase.sol";
import "./interface/IAssets.sol";
import "./util/Constants.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract PoolLP is AdminBaseUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct UserInfo {
        uint stakeAmount;       // 质押数量
        uint weight;            // 算力
        uint withdrawnAmount;   // 已领取数量
        uint preInterestPer;    // 上次计算每股收益数值
        uint accInterest;       // 当前累计收益数值
    }


    ///////////////////////////////// constant /////////////////////////////////
    ConfigBase public config;

    // 矿池产出衰减期数
    uint constant CYCLE_TIMES = 36;
    // 矿池产出衰减周期
    uint constant INTEREST_CYCLE = 30 days;
    // 矿池生命周期
    uint constant POOL_LIFE_CYCLE = CYCLE_TIMES * INTEREST_CYCLE;

    uint constant DECIMALS = 10 ** 18;
    // mint token amount each times
    function INTEREST_BASE_AMOUNT() internal pure returns (uint[] memory res) {
        uint[CYCLE_TIMES] memory const =
        [19642514412 * DECIMALS, 17678262970 * DECIMALS, 15910436673 * DECIMALS, 14319393006 * DECIMALS,
        12887453705 * DECIMALS, 11598708335 * DECIMALS, 10438837501 * DECIMALS, 9394953751 * DECIMALS,
        8455458376 * DECIMALS, 7609912538 * DECIMALS, 6848921284 * DECIMALS, 6164029156 * DECIMALS,
        5547626240 * DECIMALS, 4992863616 * DECIMALS, 4493577254 * DECIMALS, 4044219529 * DECIMALS,
        3639797576 * DECIMALS, 3275817818 * DECIMALS, 2948236036 * DECIMALS, 2653412433 * DECIMALS,
        2388071189 * DECIMALS, 2149264070 * DECIMALS, 1934337663 * DECIMALS, 1740903897 * DECIMALS,
        1566813507 * DECIMALS, 1410132156 * DECIMALS, 1269118941 * DECIMALS, 1142207047 * DECIMALS,
        1027986342 * DECIMALS, 925187708 * DECIMALS, 832668937 * DECIMALS, 749402043 * DECIMALS,
        674461839 * DECIMALS, 607015655 * DECIMALS, 546314089 * DECIMALS, 491682680 * DECIMALS];
        res = new uint[](const.length);
        for (uint i = 0; i < res.length; i++) {res[i] = const[i];}
    }


    ///////////////////////////////// storage /////////////////////////////////
    uint private _totalSupply;
    uint private _totalWeight;

    uint public startTime;
    uint public endTime;
    // time of the first user stake, pool live start at this time
    uint public firstStakeTime;
    // 上次更新每股收益时间
    uint public lastInterestUpdateTime;
    // 矿池累计每股派息
    uint public accInterestPer;

    mapping(address => UserInfo) public users;

    // 道具库存
    mapping(uint => uint) public storageNum;

    // LP矿池累计每股派息
    uint public accInterestPerLP;
    mapping(address => uint) public preInterestPerLP;
    mapping(address => uint) public accInterestLP;
    mapping(address => uint) public withdrawnAmountLP;


    event Stake(address indexed from, uint amount);
    event Withdraw(address indexed from, uint amount);
    event WithdrawReward(address indexed from, uint[] assetsId, uint[] amount);
    event WithdrawRewardLP(address indexed from, uint amount);

    function initialize() public initializer {
        BaseUpgradeable.__Base_init();

        startTime = type(uint).max;
        endTime = type(uint).max;
    }

    modifier isServing() {
        require(!isPaused, "!isPaused");
        require(address(0) != address(config), "address(0) != address(config)");
        require(block.timestamp > startTime, "block.timestamp > startTime");
        _;
    }

    function setConfig(address _value) external onlyAdmin {
        config = ConfigBase(_value);
    }

    function setStartTime(uint _value) external onlyAdmin {
        startTime = _value;
    }

    function setEndTime(uint _endTime) external onlyAdmin {
        require(0 < firstStakeTime, "setEndTime: 0 < firstStakeTime");
        require(block.timestamp <= _endTime, "setEndTime: block.timestamp <= _endTime");
        require(firstStakeTime + POOL_LIFE_CYCLE > _endTime, "setEndTime: firstStakeTime + POOL_LIFE_CYCLE > _endTime");

        endTime = _endTime;
    }

    function reset() external onlyAdmin {
        uint[] memory ids = config.ids("PoolLPConf");
        for (uint i; i < ids.length; i++) {
            storageNum[ids[i]] = config.getUint("PoolLPConf", "quantity", ids[i]);
        }
    }

    function getStorageNum(uint[] memory _assetsIds) external view returns (uint[] memory) {
        uint[] memory res = new uint[](_assetsIds.length);
        for (uint i; i < _assetsIds.length; i++) {
            res[i] = storageNum[_assetsIds[i]];
        }
        return res;
    }

    function totalSupply() public view returns (uint) {
        return _totalSupply;
    }

    function balanceOf(address _account) public view returns (uint) {
        return users[_account].stakeAmount;
    }

    function totalWeight() public view returns (uint) {
        return _totalWeight;
    }

    function weightOf(address _account) public view returns (uint) {
        return users[_account].weight;
    }

    function totalRelease() external view returns (uint) {
        return _calculateInterest(firstStakeTime, block.timestamp);
    }

    /**
     * @dev get pool info of _account
     * @return 我的算力 产出速度 质押数 已领取奖励 待领取奖励 已领取LP分红 待领取LP分红
     */
    function poolInfo(address _account) external view returns (uint[7] memory) {
        UserInfo memory userInfo = users[_account];
        if (0 == totalSupply()) {
            return [0, 0, 0, userInfo.withdrawnAmount, userInfo.accInterest, withdrawnAmountLP[_account], accInterestLP[_account]];
        }

        uint tokenPerSecond = _calculateInterest(block.timestamp - 1, block.timestamp);
        uint speed = tokenPerSecond * userInfo.weight / totalWeight();

        // current accumulating interest from lastInterestUpdateTime to now
        uint currAccInterest = _calculateInterest(lastInterestUpdateTime, block.timestamp);
        uint currAccInterestPer = accInterestPer + (currAccInterest * DECIMALS / totalWeight());

        // userInterest = user_stake_amount * (accInterestPer - user_preInterestPer)
        uint userInterest = userInfo.weight * (currAccInterestPer - userInfo.preInterestPer) / DECIMALS;
        uint currUserInterest = userInfo.accInterest + userInterest;

        uint userInterestLp = users[_account].weight * (accInterestPerLP - preInterestPerLP[_account]) / DECIMALS;
        uint currUserInterestLp = accInterestLP[_account] + userInterestLp;

        return [userInfo.weight, speed, userInfo.stakeAmount, userInfo.withdrawnAmount, currUserInterest, withdrawnAmountLP[_account], currUserInterestLp];
    }

    function stake(uint _amount) external isServing onlyExternal {
        require(endTime > block.timestamp, "stake: endTime > block.timestamp");
        require(0 < _amount, "stake: 0 < _amount");

        // update firstStakeTime & endTime at the first user stake
        if (0 == firstStakeTime) {
            firstStakeTime = block.timestamp;
            endTime = firstStakeTime + POOL_LIFE_CYCLE;
        }
        // 更新矿池累计每股派息和用户利息
        _updateInterest();
        _updateInterestLP();

        _stake(msg.sender, _amount, _amount);

        emit Stake(msg.sender, _amount);
    }

    function withdraw(uint _amount) external isServing onlyExternal {
        require(0 < _amount, "withdraw: 0 < _amount");

        // 更新矿池累计每股派息和用户利息
        _updateInterest();
        _updateInterestLP();

        _withdraw(msg.sender, _amount, _amount);

        emit Withdraw(msg.sender, _amount);
    }

    function withdrawReward(uint[] memory _assetsId, uint[] memory _amount) external isServing onlyExternal {
        // 更新矿池累计每股派息和用户利息
        _updateInterest();

        uint counter;
        for (uint i; i < _assetsId.length; i++) {
            // count total consume points
            uint point = config.getUint("PoolLPConf", "value_jf", _assetsId[i]) * _amount[i];
            require(0 < point, "withdrawReward: 0 < point");
            counter += point;
            // update assets
            IAssets(config.nameOf("Assets")).add(msg.sender, _assetsId[i], _amount[i]);
            // update storageNum
            storageNum[_assetsId[i]] -= _amount[i];
        }
        // update points
        users[msg.sender].accInterest -= counter;
        users[msg.sender].withdrawnAmount += counter;

        emit WithdrawReward(msg.sender, _assetsId, _amount);
    }

    function withdrawRewardLP() external isServing onlyExternal {
        // 更新矿池用户利息 LP
        _updateInterestLP();

        uint userInterest = accInterestLP[msg.sender];
        // update user info LP
        accInterestLP[msg.sender] = 0;
        withdrawnAmountLP[msg.sender] += userInterest;
        // transfer token
        IERC20Upgradeable(config.nameOf("DRACToken")).safeTransfer(msg.sender, userInterest);

        emit WithdrawRewardLP(msg.sender, userInterest);
    }

    function dividend(address _from, address _to, uint _amount) external {
        require(msg.sender == config.nameOf("DRACToken"), "dividend: only token");

        if (0 < totalWeight()) {
            accInterestPerLP += _amount * DECIMALS / totalWeight();
        }
    }

    function _stake(address _account, uint _amount, uint _weight) private returns (bool) {
        IERC20Upgradeable(config.nameOf("LPToken")).safeTransferFrom(msg.sender, address(this), _amount);
        _totalSupply += _amount;
        _totalWeight += _weight;
        users[_account].stakeAmount += _amount;
        users[_account].weight += _weight;
        return true;
    }

    function _withdraw(address _account, uint _amount, uint _weight) private returns (bool) {
        IERC20Upgradeable(config.nameOf("LPToken")).safeTransfer(msg.sender, _amount);
        _totalSupply -= _amount;
        _totalWeight -= _weight;
        users[_account].stakeAmount -= _amount;
        users[_account].weight -= _weight;
        return true;
    }

    /**
     * @dev update accInterestPer & user interest
     * 更新矿池累计每股派息和用户利息
     */
    function _updateInterest() private {
        UserInfo storage userInfo = users[msg.sender];
        // 1 >> update accInterestPer
        if (0 < totalWeight()) {
            // current accumulating interest from lastInterestUpdateTime to now
            uint currAccInterest = _calculateInterest(lastInterestUpdateTime, block.timestamp);
            // update accInterestPer
            accInterestPer += currAccInterest * DECIMALS / totalWeight();
            // update lastInterestUpdateTime
            lastInterestUpdateTime = block.timestamp;
        }

        // 2 >> update user interest
        // update user accumlate interest
        uint userInterest = userInfo.weight * (accInterestPer - userInfo.preInterestPer) / DECIMALS;
        userInfo.accInterest += userInterest;
        // update user preInterestPer
        userInfo.preInterestPer = accInterestPer;
    }

    function _updateInterestLP() private {
        // update user accumulate interest LP
        uint userInterest = users[msg.sender].weight * (accInterestPerLP - preInterestPerLP[msg.sender]) / DECIMALS;
        accInterestLP[msg.sender] += userInterest;
        // update user preInterestPerLP
        preInterestPerLP[msg.sender] = accInterestPerLP;
    }

    /**
     * @dev 计算一段时间内矿池产生的利息
     * @param _startTime time to start with
     * @param _endTime time to end at
     */
    function _calculateInterest(uint _startTime, uint _endTime) private view returns (uint) {
        if (0 == firstStakeTime) {
            return 0;
        }
        if (firstStakeTime > _startTime) {
            _startTime = firstStakeTime;
        }
        if (endTime < _endTime) {
            _endTime = endTime;
        }
        require(_startTime < _endTime, "_startTime < _endTime");

        // 下面的逻辑就是分段计算所有利息，可用跨段计算
        uint index1 = (_startTime - firstStakeTime) / INTEREST_CYCLE;
        uint index2 = (_endTime - firstStakeTime) / INTEREST_CYCLE;
        if (index1 == index2) {//同一段
            return INTEREST_BASE_AMOUNT()[index1] * (_endTime - _startTime) / INTEREST_CYCLE;
        }
        uint interest;
        for (uint i = index1; i < CYCLE_TIMES; i++) {//不同段
            if (i == index1 && i < index2) {
                interest = INTEREST_BASE_AMOUNT()[i] * (firstStakeTime + (i + 1) * INTEREST_CYCLE - _startTime) / INTEREST_CYCLE;
            }
            if (index1 < i && i < index2) {
                interest = interest + INTEREST_BASE_AMOUNT()[i];
            }
            if (i == index2) {
                interest = interest + INTEREST_BASE_AMOUNT()[i] * (_endTime - (firstStakeTime + i * INTEREST_CYCLE)) / INTEREST_CYCLE;
            }
        }
        return interest;
    }

}
