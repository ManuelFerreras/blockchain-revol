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

    function initialize(address initialOwner) initializer public {
        __ERC20_init("Revol", "RVL");
        __ERC20Burnable_init();
        __Ownable_init(initialOwner);
        __ERC20Permit_init("Revol");
        __UUPSUpgradeable_init();
    }

    // Swap from Token A to Token B
    function buyRevol(uint256 amountIn, address receiver) public nonReentrant onlyInitiatedAddresses returns (uint256) {
        // Prepare Swap.
        uint256 trasureFee = (amountIn * _treasureFee) / 100;
        uint256 amountInAfterFee = amountIn - trasureFee;
        uint256 revolPrice = getRate();
        uint256 amountOut = amountInAfterFee / revolPrice;

        // Transfer DAI from user to contract.
        require(IERC20(_daiAddress).transferFrom(msg.sender, address(this), amountIn), "Revol: Transfer failed");

        // Stake DAI in Aave.
        IPool(_aaveStakeAddress).supply(_daiAddress, IERC20(_daiAddress).balanceOf(address(this)), address(this), 0);

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
        uint256 amountOut = amountIn * revolPrice;

        // Burn Revol from user
        _burn(msg.sender, amountIn);

        // Unstake DAI from Aave.
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

        return daiSupply / revolSupply;
    }

    function initPool() public onlyOwner onlyPoolNotInitiated {
        require(initiated == false, "Revol: Pool already initiated");

        // Prepare Swap.
        uint256 amountIn = 1e18; // 1 DAI

        // Transfer DAI from user to contract.
        require(IERC20(_daiAddress).transferFrom(msg.sender, address(this), amountIn), "Revol: Transfer failed");

        // Stake DAI in Aave.
        IPool(_aaveStakeAddress).supply(_daiAddress, IERC20(_daiAddress).balanceOf(address(this)), address(this), 0);

        // Emit Swap event
        emit Buy(msg.sender, address(this), amountIn, 1e18);

        // Mint Revol to user
        _mint(address(this), 1e18);
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
        require(treasureFee <= 10, "Revol: Invalid treasure fee");
        _treasureFee = treasureFee;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}