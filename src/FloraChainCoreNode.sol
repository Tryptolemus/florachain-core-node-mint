// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC5192} from "./IERC5192.sol";

/// @title FloraChain Core Node (FCORE)
/// @notice Public-sale ERC-721 for MetaFlora / FloraChain core node NFTs.
/// @dev USDC mint at 399 USDC (6 decimals). Optional ETH path if priceWei > 0.
/// @dev Soulbound (EIP-5192): non-transferable after mint. Owner may burn their own token.
contract FloraChainCoreNode is ERC721, ERC721Enumerable, ERC2981, Ownable, Pausable, ReentrancyGuard, IERC5192 {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    /// @notice USDC (or test USDC) payment token.
    IERC20 public immutable usdc;

    /// @notice Price per NFT in USDC smallest units (default 399e6).
    uint256 public priceUsdc;

    /// @notice Optional ETH price; 0 disables ETH minting.
    uint256 public priceWei;

    /// @notice Maximum collection size.
    uint256 public maxSupply;

    /// @notice Max NFTs a single wallet may hold via mint.
    uint256 public maxPerWallet;

    /// @notice Public sale toggle.
    bool public saleActive;

    /// @notice Next token id to mint (1-indexed).
    uint256 public nextTokenId = 1;

    /// @notice Base URI for token metadata (trailing slash expected).
    string private _baseTokenURI;

    event Minted(address indexed minter, uint256 indexed startTokenId, uint256 quantity, bool paidInUsdc);
    event SaleActiveUpdated(bool active);
    event PriceUsdcUpdated(uint256 priceUsdc);
    event PriceWeiUpdated(uint256 priceWei);
    event MaxSupplyUpdated(uint256 maxSupply);
    event MaxPerWalletUpdated(uint256 maxPerWallet);
    event BaseURIUpdated(string baseURI);
    event WithdrawnUSDC(address indexed to, uint256 amount);
    event WithdrawnETH(address indexed to, uint256 amount);
    event RoyaltyUpdated(address indexed receiver, uint96 feeNumerator);

    error SaleNotActive();
    error InvalidQuantity();
    error MaxSupplyExceeded();
    error MaxPerWalletExceeded();
    error EthMintDisabled();
    error IncorrectEthPayment();
    error ZeroAddress();
    error NothingToWithdraw();
    /// @notice Soulbound: non-transferable (marketplace transfers and approvals blocked).
    error SoulboundNonTransferable();

    /// @param initialOwner Contract owner (treasury / ops).
    /// @param usdcToken Mainnet or testnet USDC address.
    /// @param initialBaseURI Metadata base URI.
    /// @param royaltyReceiver Address receiving 5% ERC-2981 royalties.
    constructor(address initialOwner, address usdcToken, string memory initialBaseURI, address royaltyReceiver)
        ERC721("FloraChain Core Node", "FCORE")
        Ownable(initialOwner)
    {
        if (usdcToken == address(0) || initialOwner == address(0) || royaltyReceiver == address(0)) {
            revert ZeroAddress();
        }
        usdc = IERC20(usdcToken);
        priceUsdc = 399e6; // 399 USDC (6 decimals)
        priceWei = 0; // ETH path disabled until owner sets price
        maxSupply = 2500;
        maxPerWallet = 10;
        saleActive = false;
        _baseTokenURI = initialBaseURI;
        // 5% royalty = 500 basis points out of 10_000
        _setDefaultRoyalty(royaltyReceiver, 500);
    }

    // -------------------------------------------------------------------------
    // Mint
    // -------------------------------------------------------------------------

    /// @notice Mint `qty` NFTs paying in USDC. Caller must approve this contract first.
    function mint(uint256 qty) external nonReentrant whenNotPaused {
        _enforceMintLimits(msg.sender, qty);
        uint256 cost = priceUsdc * qty;
        usdc.safeTransferFrom(msg.sender, address(this), cost);
        uint256 startId = _mintBatch(msg.sender, qty);
        emit Minted(msg.sender, startId, qty, true);
    }

    /// @notice Mint `qty` NFTs paying in ETH. Requires priceWei > 0 and exact payment.
    function mintWithETH(uint256 qty) external payable nonReentrant whenNotPaused {
        if (priceWei == 0) revert EthMintDisabled();
        _enforceMintLimits(msg.sender, qty);
        uint256 cost = priceWei * qty;
        if (msg.value != cost) revert IncorrectEthPayment();
        uint256 startId = _mintBatch(msg.sender, qty);
        emit Minted(msg.sender, startId, qty, false);
    }

    function _enforceMintLimits(address to, uint256 qty) internal view {
        if (!saleActive) revert SaleNotActive();
        if (qty == 0) revert InvalidQuantity();
        if (totalSupply() + qty > maxSupply) revert MaxSupplyExceeded();
        if (balanceOf(to) + qty > maxPerWallet) revert MaxPerWalletExceeded();
    }

    function _mintBatch(address to, uint256 qty) internal returns (uint256 startId) {
        startId = nextTokenId;
        for (uint256 i = 0; i < qty;) {
            uint256 id = startId + i;
            _safeMint(to, id);
            emit Locked(id); // EIP-5192: permanently soulbound from mint
            unchecked {
                ++i;
            }
        }
        nextTokenId = startId + qty;
    }

    // -------------------------------------------------------------------------
    // Soulbound (EIP-5192)
    // -------------------------------------------------------------------------

    /// @inheritdoc IERC5192
    /// @dev All minted tokens are permanently locked; cannot trade on OpenSea/Rarible/etc.
    function locked(uint256 tokenId) external view returns (bool) {
        _requireOwned(tokenId);
        return true;
    }

    /// @notice Burn a soulbound token you own (optional exit; transfers still blocked).
    function burn(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) revert SoulboundNonTransferable();
        _burn(tokenId);
    }

    // -------------------------------------------------------------------------
    // Owner controls
    // -------------------------------------------------------------------------

    function setSaleActive(bool active) external onlyOwner {
        saleActive = active;
        emit SaleActiveUpdated(active);
    }

    function setPriceUsdc(uint256 newPrice) external onlyOwner {
        priceUsdc = newPrice;
        emit PriceUsdcUpdated(newPrice);
    }

    function setPriceWei(uint256 newPrice) external onlyOwner {
        priceWei = newPrice;
        emit PriceWeiUpdated(newPrice);
    }

    function setMaxSupply(uint256 newMax) external onlyOwner {
        if (newMax < totalSupply()) revert MaxSupplyExceeded();
        maxSupply = newMax;
        emit MaxSupplyUpdated(newMax);
    }

    function setMaxPerWallet(uint256 newMax) external onlyOwner {
        maxPerWallet = newMax;
        emit MaxPerWalletUpdated(newMax);
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        if (receiver == address(0)) revert ZeroAddress();
        _setDefaultRoyalty(receiver, feeNumerator);
        emit RoyaltyUpdated(receiver, feeNumerator);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdrawUSDC(address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = usdc.balanceOf(address(this));
        if (bal == 0) revert NothingToWithdraw();
        usdc.safeTransfer(to, bal);
        emit WithdrawnUSDC(to, bal);
    }

    function withdrawETH(address payable to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = address(this).balance;
        if (bal == 0) revert NothingToWithdraw();
        (bool ok,) = to.call{value: bal}("");
        require(ok, "ETH transfer failed");
        emit WithdrawnETH(to, bal);
    }

    // -------------------------------------------------------------------------
    // Metadata / views
    // -------------------------------------------------------------------------

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        string memory base = _baseURI();
        return bytes(base).length > 0 ? string.concat(base, tokenId.toString(), ".json") : "";
    }

    // -------------------------------------------------------------------------
    // Transfer / approval locks + OZ v5 overrides
    // -------------------------------------------------------------------------

    /// @dev Mint (from == 0) and burn (to == 0) allowed; all wallet-to-wallet transfers revert.
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            revert SoulboundNonTransferable();
        }
        return super._update(to, tokenId, auth);
    }

    function approve(address, uint256) public pure override(ERC721, IERC721) {
        revert SoulboundNonTransferable();
    }

    function setApprovalForAll(address, bool) public pure override(ERC721, IERC721) {
        revert SoulboundNonTransferable();
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return interfaceId == type(IERC5192).interfaceId || super.supportsInterface(interfaceId);
    }
}
