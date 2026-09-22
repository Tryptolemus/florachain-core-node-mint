# Tech team handoff — FloraChain Agentic AI Node → SEED recognition

**Product:** FloraChain Core Node NFT (`FCORE`) on Ethereum — the **agentic & AI** license  
**Owner:** Greg / MetaFlora  
**Purpose:** Recognize holders for **SEED** rewards after the public mint contract is live.

## Role (do not mix with other node products)

| Product | Role |
|---------|------|
| MetaFlora Connoisseur (and other MetaFlora node SKUs) | **Peer node** — a copy of flora-1 |
| FloraChain validators | **Staking / signing** |
| **FCORE (this contract)** | **Agentic + AI power** only — Manifest rails and AI completion-pool work |

SEED gating for FCORE must stay on this contract address. Do not treat Connoisseur holders as FCORE workers or FCORE holders as validators.

This checklist is for the team that wires holder detection into MetaFlora / FloraChain SEED systems. No private keys are shared here.

---

## 1. Receive deploy artifacts

- [ ] Contract address (Ethereum mainnet): `______________________________`
- [ ] Chain id: `1` (mainnet) — confirm not Sepolia
- [ ] Etherscan link: `https://etherscan.io/address/<ADDR>`
- [ ] Deploy tx hash: `______________________________`
- [ ] Compiler: Solidity `0.8.24` (Foundry / this repo)
- [ ] Source verified on Etherscan: yes / no

## 2. Confirm collection identity

| Field | Expected |
|-------|----------|
| Name | `FloraChain Core Node` |
| Symbol | `FCORE` |
| Standard | ERC-721 (+ Enumerable) |
| Max supply | `2500` |
| Max per wallet | `10` |
| USDC price | `399000000` (399 USDC, 6 decimals) |
| Payment token | Mainnet USDC `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| Royalty | ERC-2981 5% (`500` / `10000`) |
| Soulbound | **Yes (EIP-5192)** — `locked(tokenId) == true`; transfers/approvals revert |
| Secondary markets | **Not supported** — OpenSea/Rarible listings will fail; do not assume tradability |

Quick checks (`cast`):

```bash
cast call $NFT "name()(string)" --rpc-url $MAINNET_RPC_URL
cast call $NFT "symbol()(string)" --rpc-url $MAINNET_RPC_URL
cast call $NFT "maxSupply()(uint256)" --rpc-url $MAINNET_RPC_URL
cast call $NFT "priceUsdc()(uint256)" --rpc-url $MAINNET_RPC_URL
cast call $NFT "usdc()(address)" --rpc-url $MAINNET_RPC_URL
cast call $NFT "totalSupply()(uint256)" --rpc-url $MAINNET_RPC_URL
cast call $NFT "locked(uint256)(bool)" 1 --rpc-url $MAINNET_RPC_URL
cast call $NFT "supportsInterface(bytes4)(bool)" 0xb45a3c0e --rpc-url $MAINNET_RPC_URL
```

## 3. Holder recognition methods

Prefer **on-chain reads** over off-chain snapshots where possible.

### A. Balance / ownership (simple)

- `balanceOf(address) > 0` → eligible wallet
- Optional: weight SEED by `balanceOf` (capped by maxPerWallet = 10)

### B. Enumerable enumeration

Contract inherits **ERC721Enumerable**:

- `totalSupply()`
- `tokenByIndex(i)`
- `tokenOfOwnerByIndex(owner, i)`

Useful for indexing all holders or listing a wallet’s token ids.

### C. Events to index

```
event Minted(address indexed minter, uint256 indexed startTokenId, uint256 quantity, bool paidInUsdc);
event Transfer(address indexed from, address indexed to, uint256 indexed tokenId); // ERC-721
```

Index from deploy block. Treat transfers as ownership changes for SEED eligibility.

### D. Soulbound implications for SEED

- Tokens **cannot** move between wallets after mint (except optional `burn` by owner).
- SEED eligibility is effectively **sticky to the minting wallet** unless the holder burns.
- Do **not** build marketplace-transfer indexing for FCORE; Transfer events with both non-zero addresses should never occur for this collection.
- Interface id EIP-5192: `0xb45a3c0e` — `supportsInterface` returns true.
- Optional: require `locked(tokenId) == true` as a sanity check in the indexer.

## 4. SEED product checklist

- [ ] Add `FCORE` contract address to allowlist / NFT gate config
- [ ] Confirm chain = Ethereum mainnet
- [ ] Confirm collection is **soulbound / non-transferable** (no secondary-market holder churn)
- [ ] Decide eligibility: any holder vs. min balance vs. token-id ranges
- [ ] Decide if SEED is one-time, streaming, or epoch-based
- [ ] Exclude burned tokens (`burn` by owner is available; balanceOf drops to 0)
- [ ] Marketplace transfers cannot succeed (soulbound); still key SEED off `ownerOf` / `balanceOf`
- [ ] Staging test with Sepolia address first (if used), then promote mainnet address
- [ ] Document admin who can update the recognized contract address
- [ ] Notify ops when indexing is live; Greg can open `saleActive`
- [ ] Index FCORE as **agentic/AI worker license**, not as peer or validator eligibility

## 5. Security / ops notes for tech

- Sale is gated by `saleActive` (owner). Holders only appear after mints.
- Owner can `pause` mints; existing holdings remain valid for recognition.
- Do **not** use deployer private keys in SEED services — read-only RPC is enough.
- Royalty (ERC-2981) is marketplace signaling only; unrelated to SEED.

## 6. Contacts / links

- Repo: https://github.com/Tryptolemus/florachain-core-node-mint
- FloraChain: https://florachain.xyz
- MetaFlora: https://metaflora.xyz
- Mint UI (static): `mint-app/index.html` in this repo

## 7. Sign-off

| Role | Name | Date | Initials |
|------|------|------|----------|
| Deploy (Greg) | | | |
| SEED integration | | | |
| QA | | | |

**Handoff complete when:** mainnet address is in SEED config, a test holder is recognized in staging/prod, and Greg is cleared to set `saleActive(true)`.
