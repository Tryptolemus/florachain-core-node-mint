// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {FloraChainCoreNode} from "../src/FloraChainCoreNode.sol";

/// @notice Deploy FloraChainCoreNode to Sepolia or Ethereum mainnet.
/// @dev Broadcast instructions only — never commit private keys.
///
/// Sepolia:
///   forge script script/Deploy.s.sol:Deploy \
///     --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
///
/// Mainnet:
///   forge script script/Deploy.s.sol:Deploy \
///     --rpc-url $MAINNET_RPC_URL --broadcast --verify -vvvv
///
/// Required env:
///   PRIVATE_KEY     — deployer key (local env only; never commit)
///   USDC_ADDRESS    — payment token (mainnet USDC: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)
///   INITIAL_OWNER   — owner / withdraw address
///   ROYALTY_RECEIVER— ERC-2981 royalty receiver (often same as owner)
///   BASE_URI        — metadata base, e.g. ipfs://Qm.../ or https://.../
contract Deploy is Script {
    /// @dev Canonical Ethereum mainnet USDC.
    address constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address initialOwner = vm.envAddress("INITIAL_OWNER");
        address royaltyReceiver = vm.envAddress("ROYALTY_RECEIVER");
        string memory baseURI = vm.envString("BASE_URI");

        address usdc = vm.envOr("USDC_ADDRESS", MAINNET_USDC);

        vm.startBroadcast(pk);
        FloraChainCoreNode nft = new FloraChainCoreNode(initialOwner, usdc, baseURI, royaltyReceiver);
        vm.stopBroadcast();

        console2.log("FloraChainCoreNode deployed at:", address(nft));
        console2.log("USDC:", usdc);
        console2.log("Owner:", initialOwner);
        console2.log("Royalty receiver:", royaltyReceiver);
        console2.log("Next: setSaleActive(true) when ready to open mint");
    }
}
