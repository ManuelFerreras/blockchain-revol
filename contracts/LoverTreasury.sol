// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract LoverTreasury is Initializable, UUPSUpgradeable, ReentrancyGuardUpgradeable, AccessControlUpgradeable {
    bytes32 public constant EXECUTION_ROLE = keccak256("EXECUTION_ROLE");
    address public uniswapRouterAddress;

    event BuyBack(address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);

    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin, address _uniswapRouterAddress) initializer public {
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        uniswapRouterAddress = _uniswapRouterAddress;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(DEFAULT_ADMIN_ROLE)
        override
    {}

    function buyBack(address tokenA, address tokenB, uint256 amountA, uint256 amountOutMin, uint256 deadline) external onlyRole(EXECUTION_ROLE) nonReentrant {
        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountA), "Transfer of tokenA failed");
        require(IERC20(tokenA).approve(uniswapRouterAddress, amountA), "Approval of tokenA failed");

        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        IUniswapV2Router(uniswapRouterAddress).swapExactTokensForTokens(
            amountA,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        uint256 amountB = IERC20(tokenB).balanceOf(address(this));
        emit BuyBack(tokenA, tokenB, amountA, amountB);
    }
}
