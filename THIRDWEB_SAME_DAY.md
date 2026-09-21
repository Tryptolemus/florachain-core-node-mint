# THIRDWEB same-day fallback — $399 USDC NFT Drop

Use this if Foundry mainnet deploy is too slow tonight. Goal: launch **FloraChain Core Node** priced at **399 USDC** via [thirdweb.com](https://thirdweb.com) NFT Drop (or equivalent Token Drop / NFT Collection with claim conditions).

**Still:** do not paste private keys into chat. Use thirdweb’s browser wallet connect.

## Soulbound requirement (critical)

Greg requires **FCORE to be soulbound (non-transferable)**. Standard thirdweb **NFT Drop is transferable**.

- Prefer deploying **this repo's Foundry `FloraChainCoreNode`** (EIP-5192) for true soulbound.
- If you must use thirdweb tonight: search for a **Soulbound / Non-Transferable NFT** thirdweb template, enable transfer restrictions, and confirm `transferFrom` reverts between wallets before public sale.
- Tell tech which path you used — SEED indexing assumptions differ if tokens are tradable.


---

## 10-step checklist

1. **Create / log into thirdweb**  
   Go to https://thirdweb.com/dashboard and connect the **deployer / treasury** wallet Greg controls.

2. **Pick network**  
   Select **Ethereum** (mainnet) for production. Use **Sepolia** only for a quick rehearsal.

3. **Create NFT Drop**  
   Dashboard → **Contracts** → **Deploy** → choose **NFT Drop** (lazy mint + claim conditions).  
   Name: `FloraChain Core Node` · Symbol: `FCORE`.

4. **Upload artwork & metadata**  
   Use `metadata/fcore.svg` from this repo (or a PNG export).  
   Set description referencing FloraChain / MetaFlora and links to florachain.xyz + metaflora.xyz.  
   Lazy-mint **up to 2500** NFTs (or mint a batch and add more later if UI caps batch size).

5. **Set claim condition — USDC price**  
   Add a public claim phase:
   - Price: **399**
   - Currency: **USDC** (mainnet `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`)
   - Max claimable per wallet: **10**
   - Max claimable total: **2500**
   - Start time: when Greg is ready (or start paused / in the future)

6. **Platform / recipient fees**  
   Set primary sale recipient = treasury.  
   Set royalty **5%** to the same or designated royalty wallet (matches Foundry contract intent).

7. **Deploy contract on-chain**  
   Confirm gas in wallet; wait for success. **Copy the contract address.**

8. **Smoke-test claim**  
   From a small alt wallet: approve USDC → claim 1 NFT on Sepolia first (if testing), then on mainnet with 399 USDC.  
   Confirm token appears in wallet / OpenSea (may take a few minutes).

9. **Hand address to tech**  
   Fill `TECH_TEAM_HANDOFF.md` with the thirdweb contract address.  
   Note: thirdweb Drop interfaces differ from `FloraChainCoreNode.sol` — tech should use:
   - `balanceOf` / `ownerOf` / Transfer events (still ERC-721), or
   - thirdweb indexer / dashboard export for holders  
   Do **not** assume custom `Minted` or `mint(uint256)` ABIs from this Foundry repo.

10. **Point mint front-end**  
    Either:
    - Use thirdweb’s hosted claim page / embed, **or**
    - Update branding links and share the claim URL with buyers  
    Keep florachain.xyz and metaflora.xyz in copy.

---

## After thirdweb launch

- [ ] Save contract address + dashboard link in the team vault  
- [ ] Export ABI from thirdweb if custom UI is needed later  
- [ ] When time allows, optionally migrate messaging to the Foundry `FloraChainCoreNode` collection — treat as a **new** collection unless a bridge/migration is planned  
- [ ] Complete SEED recognition using ERC-721 ownership, not Foundry-specific events  

## Why this fallback exists

Foundry path gives full control (custom USDC `mint`, pause, withdraw, enumerable). Thirdweb path minimizes tonight’s operational risk: wallet UI deploy, USDC claim condition, hosted claim page.
