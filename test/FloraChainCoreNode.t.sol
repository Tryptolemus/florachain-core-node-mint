// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {FloraChainCoreNode} from "../src/FloraChainCoreNode.sol";
import {MockUSDC} from "./MockUSDC.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract FloraChainCoreNodeTest is Test, IERC721Receiver {
    FloraChainCoreNode internal nft;
    MockUSDC internal usdc;

    address internal owner = makeAddr("owner");
    address internal royalty = makeAddr("royalty");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant PRICE = 399e6;

    function setUp() public {
        usdc = new MockUSDC();
        nft = new FloraChainCoreNode(owner, address(usdc), "https://meta.example/", royalty);

        usdc.mint(alice, 10_000e6);
        usdc.mint(bob, 10_000e6);

        vm.prank(alice);
        usdc.approve(address(nft), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(nft), type(uint256).max);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _activateSale() internal {
        vm.prank(owner);
        nft.setSaleActive(true);
    }

    function test_constructorDefaults() public view {
        assertEq(nft.name(), "FloraChain Core Node");
        assertEq(nft.symbol(), "FCORE");
        assertEq(nft.priceUsdc(), PRICE);
        assertEq(nft.priceWei(), 0);
        assertEq(nft.maxSupply(), 2500);
        assertEq(nft.maxPerWallet(), 10);
        assertFalse(nft.saleActive());
        assertEq(address(nft.usdc()), address(usdc));
        (address recv, uint256 royaltyAmt) = nft.royaltyInfo(1, 10_000);
        assertEq(recv, royalty);
        assertEq(royaltyAmt, 500); // 5% of 10000
    }

    function test_mintUSDC_success() public {
        _activateSale();
        uint256 beforeBal = usdc.balanceOf(alice);

        vm.prank(alice);
        nft.mint(2);

        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.ownerOf(2), alice);
        assertEq(nft.totalSupply(), 2);
        assertEq(nft.nextTokenId(), 3);
        assertEq(usdc.balanceOf(alice), beforeBal - 2 * PRICE);
        assertEq(usdc.balanceOf(address(nft)), 2 * PRICE);
        assertEq(nft.tokenURI(1), "https://meta.example/1.json");
    }

    function test_mintRevertsWhenSaleInactive() public {
        vm.prank(alice);
        vm.expectRevert(FloraChainCoreNode.SaleNotActive.selector);
        nft.mint(1);
    }

    function test_mintRevertsZeroQty() public {
        _activateSale();
        vm.prank(alice);
        vm.expectRevert(FloraChainCoreNode.InvalidQuantity.selector);
        nft.mint(0);
    }

    function test_mintRevertsMaxPerWallet() public {
        _activateSale();
        vm.prank(alice);
        nft.mint(10);
        vm.prank(alice);
        vm.expectRevert(FloraChainCoreNode.MaxPerWalletExceeded.selector);
        nft.mint(1);
    }

    function test_mintRevertsMaxSupply() public {
        _activateSale();
        vm.prank(owner);
        nft.setMaxSupply(3);
        vm.prank(alice);
        nft.mint(3);
        vm.prank(bob);
        vm.expectRevert(FloraChainCoreNode.MaxSupplyExceeded.selector);
        nft.mint(1);
    }

    function test_ethMintDisabledByDefault() public {
        _activateSale();
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert(FloraChainCoreNode.EthMintDisabled.selector);
        nft.mintWithETH{value: 0.1 ether}(1);
    }

    function test_ethMintSuccess() public {
        _activateSale();
        uint256 ethPrice = 0.1 ether;
        vm.prank(owner);
        nft.setPriceWei(ethPrice);
        vm.deal(alice, 1 ether);

        vm.prank(alice);
        nft.mintWithETH{value: ethPrice * 2}(2);

        assertEq(nft.balanceOf(alice), 2);
        assertEq(address(nft).balance, ethPrice * 2);
    }

    function test_ethMintIncorrectPayment() public {
        _activateSale();
        vm.prank(owner);
        nft.setPriceWei(0.1 ether);
        vm.deal(alice, 1 ether);

        vm.prank(alice);
        vm.expectRevert(FloraChainCoreNode.IncorrectEthPayment.selector);
        nft.mintWithETH{value: 0.05 ether}(1);
    }

    function test_withdrawUSDC() public {
        _activateSale();
        vm.prank(alice);
        nft.mint(1);

        vm.prank(owner);
        nft.withdrawUSDC(owner);
        assertEq(usdc.balanceOf(owner), PRICE);
        assertEq(usdc.balanceOf(address(nft)), 0);
    }

    function test_withdrawETH() public {
        _activateSale();
        vm.prank(owner);
        nft.setPriceWei(0.2 ether);
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        nft.mintWithETH{value: 0.2 ether}(1);

        uint256 before = owner.balance;
        vm.prank(owner);
        nft.withdrawETH(payable(owner));
        assertEq(owner.balance, before + 0.2 ether);
    }

    function test_pauseBlocksMint() public {
        _activateSale();
        vm.prank(owner);
        nft.pause();
        vm.prank(alice);
        vm.expectRevert();
        nft.mint(1);
    }

    function test_ownerSetters() public {
        vm.startPrank(owner);
        nft.setPriceUsdc(100e6);
        nft.setMaxPerWallet(5);
        nft.setBaseURI("ipfs://cid/");
        nft.setSaleActive(true);
        nft.setDefaultRoyalty(bob, 250);
        vm.stopPrank();

        assertEq(nft.priceUsdc(), 100e6);
        assertEq(nft.maxPerWallet(), 5);
        (address r, uint256 a) = nft.royaltyInfo(1, 10_000);
        assertEq(r, bob);
        assertEq(a, 250);
    }

    function test_enumerable() public {
        _activateSale();
        vm.prank(alice);
        nft.mint(3);
        assertEq(nft.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(nft.tokenByIndex(2), 3);
    }

    function test_supportsInterfaces() public view {
        // ERC721
        assertTrue(nft.supportsInterface(0x80ac58cd));
        // ERC721Enumerable
        assertTrue(nft.supportsInterface(0x780e9d63));
        // ERC2981
        assertTrue(nft.supportsInterface(0x2a55205a));
        // EIP-5192 soulbound
        assertTrue(nft.supportsInterface(0xb45a3c0e));
    }

    function test_soulbound_transferReverts() public {
        _activateSale();
        vm.prank(alice);
        nft.mint(1);

        vm.prank(alice);
        vm.expectRevert(FloraChainCoreNode.SoulboundNonTransferable.selector);
        nft.transferFrom(alice, bob, 1);
    }

    function test_soulbound_safeTransferReverts() public {
        _activateSale();
        vm.prank(alice);
        nft.mint(1);

        vm.prank(alice);
        vm.expectRevert(FloraChainCoreNode.SoulboundNonTransferable.selector);
        nft.safeTransferFrom(alice, bob, 1);
    }

    function test_soulbound_approveReverts() public {
        _activateSale();
        vm.prank(alice);
        nft.mint(1);

        vm.prank(alice);
        vm.expectRevert(FloraChainCoreNode.SoulboundNonTransferable.selector);
        nft.approve(bob, 1);
    }

    function test_soulbound_setApprovalForAllReverts() public {
        _activateSale();
        vm.prank(alice);
        nft.mint(1);

        vm.prank(alice);
        vm.expectRevert(FloraChainCoreNode.SoulboundNonTransferable.selector);
        nft.setApprovalForAll(bob, true);
    }

    function test_soulbound_lockedTrue() public {
        _activateSale();
        vm.prank(alice);
        nft.mint(1);
        assertTrue(nft.locked(1));
    }

    function test_soulbound_burnByOwner() public {
        _activateSale();
        vm.prank(alice);
        nft.mint(1);
        assertEq(nft.balanceOf(alice), 1);
        vm.prank(alice);
        nft.burn(1);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.totalSupply(), 0);
    }

    function test_soulbound_burnByNonOwnerReverts() public {
        _activateSale();
        vm.prank(alice);
        nft.mint(1);
        vm.prank(bob);
        vm.expectRevert(FloraChainCoreNode.SoulboundNonTransferable.selector);
        nft.burn(1);
    }

    function test_onlyOwnerGuards() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.setSaleActive(true);
    }
}
