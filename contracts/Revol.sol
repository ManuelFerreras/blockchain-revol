// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";

contract Revol is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, AccessControlUpgradeable {
    address private _daiAddress;
    address private _lpDaiAddress;
    address private _aaveStakeAddress;
    address private _treasureReceiverAddress;

    uint256 private _treasureFee;
    uint256 private _totalStakedLP;
    uint256 private immutable decimalFactor = 1e18;

    bool public initiated;

    bytes32 public constant DISCOUNT_ROLE = keccak256("DISCOUNT_ROLE");

    // Events
    event Buy(address indexed user, address indexed receiver, uint256 amountIn, uint256 amountOut);
    event Sell(address indexed user, uint256 amountIn, uint256 amountOut);
    event Claimed(uint256 amount);

    constructor() {
        _disableInitializers();
    }

    modifier onlyInitiatedAddresses() {
        require(_daiAddress != address(0), "Revol: Bad DAI");
        require(_lpDaiAddress != address(0), "Revol: Bad LP");
        require(_aaveStakeAddress != address(0), "Revol: Bad Aave");
        require(initiated == true, "Revol: Bad Pool");
        _;
    }

    modifier onlyPoolNotInitiated() {
        require(initiated == false, "Revol: Already");
        _;
    }

    function initialize(address defaultAdmin, uint256 treasureFee_, address daiAddress_, address lpDaiAddress_, address aaveStakeAddress_, address treasureReceiverAddress_) initializer public {
        __ERC20_init("Revol", "RVL");
        __ERC20Burnable_init();
        __ERC20Permit_init("Revol");
        __UUPSUpgradeable_init();

        _treasureFee = treasureFee_;
        _daiAddress = daiAddress_;
        _lpDaiAddress = lpDaiAddress_;
        _aaveStakeAddress = aaveStakeAddress_;
        _treasureReceiverAddress = treasureReceiverAddress_;
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    // Swap from Token A to Token B
    function buyRevol(uint256 amountIn, address receiver) public nonReentrant onlyInitiatedAddresses returns (uint256) {
        // Prepare Swap.
        uint256 trasureFee = (amountIn * _treasureFee) / 100;
        uint256 amountInAfterFee = amountIn - trasureFee;
        uint256 revolPrice = getRate();
        uint256 amountOut = amountInAfterFee * decimalFactor / revolPrice;

        IERC20 _dai = IERC20(_daiAddress);

        // Transfer DAI from user to contract.
        _dai.approve(_aaveStakeAddress, amountIn);
        require(_dai.transferFrom(msg.sender, address(this), amountIn), "Revol: Fail");

        // Stake DAI in Aave.
        uint256 _daiBalance = _dai.balanceOf(address(this));
        IPool(_aaveStakeAddress).supply(_daiAddress, _daiBalance, address(this), 0);
        _totalStakedLP += _daiBalance;

        // Emit Swap event
        emit Buy(msg.sender, receiver, amountIn, amountOut);

        // Mint Revol to user
        _mint(receiver, amountOut);

        return amountOut;
    }

    // Swap from Token A to Token B supporting custom fee amount.
    function buyRevolWithFee(uint256 amountIn, address receiver, uint256 fee) public nonReentrant onlyInitiatedAddresses onlyRole(DISCOUNT_ROLE) returns (uint256) {
        // Prepare Swap.
        uint256 totalAmountIn = amountIn + fee;
        uint256 revolPrice = getRate();
        uint256 amountOut = amountIn * decimalFactor / revolPrice;

        IERC20 _dai = IERC20(_daiAddress);

        // Transfer DAI from user to contract.
        _dai.approve(_aaveStakeAddress, totalAmountIn);
        require(_dai.transferFrom(msg.sender, address(this), totalAmountIn), "Revol: Fail");

        // Stake DAI in Aave.
        uint256 _daiBalance = _dai.balanceOf(address(this));
        IPool(_aaveStakeAddress).supply(_daiAddress, _daiBalance, address(this), 0);
        _totalStakedLP += _daiBalance;

        // Emit Swap event
        emit Buy(msg.sender, receiver, amountIn, amountOut);

        // Mint Revol to user
        _mint(receiver, amountOut);

        return amountOut;
    }

    // Swap from Token B to Token A
    function sellRevol(uint256 amountIn) public nonReentrant onlyInitiatedAddresses returns (uint256) {
        // Prepare Swap.
        uint256 revolPrice = getRate();
        uint256 amountOut = amountIn * revolPrice / decimalFactor;

        // Burn Revol from user
        _burn(msg.sender, amountIn);

        // Unstake DAI from Aave.
        IERC20(_lpDaiAddress).approve(_aaveStakeAddress, amountOut);
        IPool(_aaveStakeAddress).withdraw(_daiAddress, amountOut, address(this));

        // Transfer DAI from contract to user.
        require(IERC20(_daiAddress).transfer(msg.sender, amountOut), "Revol: Fail");
        _totalStakedLP -= amountOut;

        // Emit Swap event
        emit Sell(msg.sender, amountIn, amountOut);

        return amountOut;
    }

    function getRate() public view onlyInitiatedAddresses returns (uint256) {
        uint256 revolSupply = IERC20(address(this)).totalSupply();
        uint256 daiSupply = _totalStakedLP;

        return daiSupply * decimalFactor / revolSupply;
    }

    function initPool() public onlyRole(DEFAULT_ADMIN_ROLE) onlyPoolNotInitiated {
        IERC20 _dai = IERC20(_daiAddress);

        // Prepare Swap.
        uint256 amountIn = 100 * decimalFactor; // 100 DAI

        // Transfer DAI from user to contract.
        require(_dai.transferFrom(msg.sender, address(this), amountIn), "Revol: Fail");

        uint256 _daiBalance = _dai.balanceOf(address(this));

        // Stake DAI in Aave.
        _dai.approve(_aaveStakeAddress, _daiBalance);
        IPool(_aaveStakeAddress).supply(_daiAddress, _daiBalance, address(this), 0);
        _totalStakedLP += _daiBalance;

        // Emit Swap event
        emit Buy(msg.sender, address(this), amountIn, amountIn);

        // Mint Revol to user
        _mint(address(this), amountIn);

        // Mark pool as initiated.
        initiated = true;
    }

    function getLPEarnings() public view onlyInitiatedAddresses returns (uint256) {
        uint256 _lpDaiBalance = IERC20(_lpDaiAddress).balanceOf(address(this));
        uint256 _earnings = _lpDaiBalance - _totalStakedLP;

        return _earnings;
    }

    function claimLPEarnings() public onlyInitiatedAddresses {
        uint256 _earnings = getLPEarnings();
        require(_earnings > 0, "Revol: No earnings to claim");
        require(_treasureReceiverAddress != address(0), "Revol: Invalid treasure receiver address");

        // Unstake DAI from Aave.
        IERC20(_lpDaiAddress).approve(_aaveStakeAddress, _earnings);
        IPool(_aaveStakeAddress).withdraw(_daiAddress, _earnings, address(this));

        uint256 _daiAmount = IERC20(_daiAddress).balanceOf(address(this));

        // Transfer DAI from contract to user.
        require(IERC20(_daiAddress).transfer(_treasureReceiverAddress, _daiAmount), "Revol: Transfer failed");
        emit Claimed(_daiAmount);
    }

    function setDaiAddress(address daiAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _daiAddress = daiAddress;
    }

    function setLpDaiAddress(address lpDaiAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _lpDaiAddress = lpDaiAddress;
    }

    function setAaveStakeAddress(address aaveStakeAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _aaveStakeAddress = aaveStakeAddress;
    }

    function setTreasureFee(uint256 treasureFee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(treasureFee <= 100, "Revol: Invalid treasure fee");
        _treasureFee = treasureFee;
    }

    function setTreasureReceiverAddress(address treasureReceiverAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _treasureReceiverAddress = treasureReceiverAddress;
    }


    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(DEFAULT_ADMIN_ROLE)
        override
    {}
}