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

    // Events
    event Swap(address indexed user, uint256 amountIn, uint256 amountOut);

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) initializer public {
        __ERC20_init("Revol", "RVL");
        __ERC20Burnable_init();
        __Ownable_init(initialOwner);
        __ERC20Permit_init("Revol");
        __UUPSUpgradeable_init();
    }

    // Swap from Token A to Token B
    function buyRevol(uint256 amountIn) public nonReentrant {
        require(_daiAddress != address(0), "Revol: DAI Token not set");

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
        emit Swap(msg.sender, amountIn, amountOut);

        // Mint Revol to user
        _mint(msg.sender, amountOut);
    }

    function getRate() public view returns (uint256) {
        require(_lpDaiAddress != address(0), "Revol: LP DAI Token not set");

        uint256 totalSupply = IERC20(address(this)).totalSupply();
        uint256 balance = IERC20(_lpDaiAddress).balanceOf(address(this));

        return balance / totalSupply;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}