// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";

contract Revol is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    address private _daiAddress;
    address private _lpDaiAddress;
    address private _aaveStakeAddress;

    uint256 private _treasureFee;
    uint256 private immutable decimalFactor = 1e18;

    bool public initiated;

    // Events
    event Buy(address indexed user, address indexed receiver, uint256 amountIn, uint256 amountOut);
    event Sell(address indexed user, uint256 amountIn, uint256 amountOut);

    constructor() {
        _disableInitializers();
    }

    modifier onlyInitiatedAddresses() {
        require(_daiAddress != address(0), "Revol: DAI Token not set");
        require(_lpDaiAddress != address(0), "Revol: LP DAI Token not set");
        require(_aaveStakeAddress != address(0), "Revol: Aave Stake Address not set");
        require(initiated == true, "Revol: Pool not initiated");
        _;
    }

    modifier onlyPoolNotInitiated() {
        require(initiated == false, "Revol: Pool already initiated");
        _;
    }

    function initialize(address initialOwner, uint256 treasureFee_, address daiAddress_, address lpDaiAddress_, address aaveStakeAddress_) initializer public {
        __ERC20_init("Revol", "RVL");
        __ERC20Burnable_init();
        __Ownable_init(initialOwner);
        __ERC20Permit_init("Revol");
        __UUPSUpgradeable_init();

        _treasureFee = treasureFee_;
        _daiAddress = daiAddress_;
        _lpDaiAddress = lpDaiAddress_;
        _aaveStakeAddress = aaveStakeAddress_;
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
        require(_dai.transferFrom(msg.sender, address(this), amountIn), "Revol: Transfer failed");

        // Stake DAI in Aave.
        IPool(_aaveStakeAddress).supply(_daiAddress, _dai.balanceOf(address(this)), address(this), 0);

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
        require(IERC20(_daiAddress).transfer(msg.sender, amountOut), "Revol: Transfer failed");

        // Emit Swap event
        emit Sell(msg.sender, amountIn, amountOut);

        return amountOut;
    }

    function getRate() public view onlyInitiatedAddresses returns (uint256) {
        uint256 revolSupply = IERC20(address(this)).totalSupply();
        uint256 daiSupply = IERC20(_lpDaiAddress).balanceOf(address(this));

        return daiSupply * decimalFactor / revolSupply;
    }

    function initPool() public onlyOwner onlyPoolNotInitiated {
        require(initiated == false, "Revol: Pool already initiated");

        IERC20 _dai = IERC20(_daiAddress);

        // Prepare Swap.
        uint256 amountIn = 100 * decimalFactor; // 100 DAI

        // Transfer DAI from user to contract.
        require(_dai.transferFrom(msg.sender, address(this), amountIn), "Revol: Transfer failed");

        uint256 _daiBalance = _dai.balanceOf(address(this));

        // Stake DAI in Aave.
        _dai.approve(_aaveStakeAddress, _daiBalance);
        IPool(_aaveStakeAddress).supply(_daiAddress, _daiBalance, address(this), 0);

        // Emit Swap event
        emit Buy(msg.sender, address(this), amountIn, amountIn);

        // Mint Revol to user
        _mint(address(this), amountIn);

        // Mark pool as initiated.
        initiated = true;
    }

    function setDaiAddress(address daiAddress) public onlyOwner {
        _daiAddress = daiAddress;
    }

    function setLpDaiAddress(address lpDaiAddress) public onlyOwner {
        _lpDaiAddress = lpDaiAddress;
    }

    function setAaveStakeAddress(address aaveStakeAddress) public onlyOwner {
        _aaveStakeAddress = aaveStakeAddress;
    }

    function setTreasureFee(uint256 treasureFee) public onlyOwner {
        require(treasureFee <= 100, "Revol: Invalid treasure fee");
        _treasureFee = treasureFee;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}