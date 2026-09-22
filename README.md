# FloraChain Core Node (FCORE) — agentic & AI

Public-sale Ethereum NFT for the **FloraChain Agentic AI Node** — symbol `FCORE`.

This license is **only** for powering agentic execution and AI work on FloraChain. It is a different machine from the other two roles on the network:

| Role | Who sells / runs it | What it does |
|------|---------------------|--------------|
| **Peer / Connoisseur** | MetaFlora Connoisseur (and Industry / Home Grow peers) | A **copy of the chain**. Replays flora-1, holds history, verifies state. |
| **Validator** | Validator set (founding core today; set opening) | **Staking and block signing**. Consensus keys, slashing, governance weight. |
| **FCORE (this repo)** | This mint | **Agentic + AI power** for FloraChain: Manifest MCP rails (`identity`, `quote`, `pay`, `attest`, `revoke`) and, when activated, AI completion-pool work. |

FCORE does **not** make the holder a peer replica or a validator. The NFT is the license. Hosting the agent/AI worker is separate infrastructure (see below).

- **Price:** exactly **399 USDC** per NFT (6 decimals → `399e6`)
- **Supply:** max **2500**
- **Per wallet:** max **10**
- **Royalty:** ERC-2981 **5%** to configured receiver
- **Soulbound (EIP-5192):** **non-transferable** after mint — cannot be traded on OpenSea, Rarible, or any secondary market. Approvals are disabled. Owner may `burn` their own token.
- **Payment:** USDC `transferFrom` (optional ETH path if owner sets `priceWei`)

Owner: Greg / MetaFlora. After deploy, pass the contract address to the tech team for **SEED** holder recognition (see `TECH_TEAM_HANDOFF.md`).

> This repo does **not** contain private keys. Do **not** commit `.env`. Deploy from your own machine.

## What the holder is licensed to power

When the agent layer ships (site: Month 6):

- Connect a customer-owned agent (Claude, GPT, in-house) to **Manifest** as an MCP server
- Exercise the five calls: `identity` · `quote` · `pay` · `attest` · `revoke`
- After AI completion pools activate: run a **whitelisted relay / pool worker** that puts inference under on-chain consensus (deposit → multi-node result → slash divergence)

Bring-your-own-model. FCORE is not a GPU NFT and not a chain replica.

## Hosting this node (not a peer, not a validator)

Do **not** size this like a Connoisseur archive box or a Cosmos validator+sentry.

| Piece | Need |
|-------|------|
| Mint site | Static host (Vercel is fine) |
| Manifest MCP worker | Always-on HTTPS process (not serverless-only). Agent credential. Low latency to flora-1 RPC. |
| Completion-pool worker | Separate box once pools activate: 8+ CPU, 32+ GB RAM, disk for artifacts/IPFS. GPU only if *you* host inference. |
| flora-1 access | Public gateway today: `https://testnet-gateway.metaflora.xyz` — this node queries/settles; it does not store the full chain. |

Peer copies of the chain and validator keys live in other products / other machines.

## Package layout

```
src/FloraChainCoreNode.sol   # ERC721 + Enumerable + ERC2981 + EIP-5192 soulbound + Ownable + Pausable + ReentrancyGuard
src/IERC5192.sol              # Minimal soulbound interface
script/Deploy.s.sol          # Sepolia / mainnet deploy script
test/                        # forge tests
mint-app/index.html          # static ethers.js mint page (brand greens)
metadata/                    # sample JSON + SVG artwork
TECH_TEAM_HANDOFF.md         # SEED recognition checklist
THIRDWEB_SAME_DAY.md         # thirdweb fallback if Foundry deploy is slow
```

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`, `cast`)
- An RPC URL (Alchemy / Infura / etc.)
- Deployer wallet with ETH for gas
- USDC address for the target chain

### Mainnet USDC

`0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`

For Sepolia, deploy a mock USDC or use a known test USDC and set `USDC_ADDRESS`.

## Setup

```bash
git clone https://github.com/Tryptolemus/florachain-core-node-mint.git
cd florachain-core-node-mint
forge install
cp .env.example .env   # fill values locally — never commit
```

## Tests

```bash
forge test -vv
```

## Environment

See `.env.example`:

| Variable | Purpose |
|----------|---------|
| `PRIVATE_KEY` | Deployer key (local only) |
| `SEPOLIA_RPC_URL` / `MAINNET_RPC_URL` | JSON-RPC |
| `ETHERSCAN_API_KEY` | Verification |
| `USDC_ADDRESS` | Payment token |
| `INITIAL_OWNER` | Ownable owner / withdraw target |
| `ROYALTY_RECEIVER` | ERC-2981 5% receiver |
| `BASE_URI` | Metadata base ending in `/` |

## Deploy (broadcast — you run this)

### 1) Sepolia dry-run then broadcast

```bash
source .env

forge script script/Deploy.s.sol:Deploy \
  --rpc-url $SEPOLIA_RPC_URL \
  -vvvv

# when ready:
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast --verify -vvvv
```

### 2) Ethereum mainnet

```bash
source .env

# simulate first
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $MAINNET_RPC_URL \
  -vvvv

forge script script/Deploy.s.sol:Deploy \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast --verify -vvvv
```

### 3) Post-deploy owner calls

```bash
# Open sale
cast send $NFT "setSaleActive(bool)" true --rpc-url $MAINNET_RPC_URL --private-key $PRIVATE_KEY

# Optional ETH price (0 = disabled)
# cast send $NFT "setPriceWei(uint256)" 100000000000000000 --rpc-url $MAINNET_RPC_URL --private-key $PRIVATE_KEY

# Update metadata base when IPFS is ready
# cast send $NFT "setBaseURI(string)" "ipfs://QmYourCid/" --rpc-url $MAINNET_RPC_URL --private-key $PRIVATE_KEY

# Withdraw USDC proceeds
# cast send $NFT "withdrawUSDC(address)" $TREASURY --rpc-url $MAINNET_RPC_URL --private-key $PRIVATE_KEY
```

Record the deployed address and send it to tech (see `TECH_TEAM_HANDOFF.md`).

## Buyer flow

1. Connect wallet on **Ethereum** (or Sepolia for test).
2. Hold enough **USDC** + ETH for gas.
3. Open `mint-app/index.html` (or host it), set `CONFIG.contractAddress`.
4. Choose quantity (1–10).
5. **Approve** USDC for the NFT contract (`399e6 * qty`).
6. **Mint** — on success, token ids are shown from the `Minted` event.
7. View on explorer once metadata URI is live. **Tokens will not list/trade on OpenSea or other marketplaces** — they are soulbound.

### Local mint page

```bash
cd mint-app && python3 -m http.server 8080
# open http://localhost:8080
```

## Metadata

- `metadata/sample.json` — OpenSea-compatible example (Agentic AI Node traits)
- `metadata/fcore.svg` — simple professional node artwork

Upload the folder (or generated per-token JSON) to IPFS, then set `BASE_URI` / `setBaseURI` to `ipfs://<CID>/` so `tokenURI(id)` → `ipfs://<CID>/<id>.json`.

## Contract summary

| Function | Who | Notes |
|----------|-----|-------|
| `mint(qty)` | public | Pulls `priceUsdc * qty` USDC; emits EIP-5192 `Locked` |
| `burn(tokenId)` | token owner | Optional burn only; no P2P transfer |
| `locked(tokenId)` | view | Always `true` (EIP-5192) |
| `mintWithETH(qty)` | public | Only if `priceWei > 0` |
| `setSaleActive` | owner | Gate sale |
| `setPriceUsdc` / `setPriceWei` | owner | Pricing |
| `setMaxSupply` / `setMaxPerWallet` | owner | Limits |
| `setBaseURI` | owner | Metadata |
| `pause` / `unpause` | owner | Emergency |
| `withdrawUSDC` / `withdrawETH` | owner | Proceeds |
| `setDefaultRoyalty` | owner | ERC-2981 |

## Same-day fallback

If Foundry mainnet deploy is too slow tonight, use **`THIRDWEB_SAME_DAY.md`** for a 10-step $399 USDC NFT Drop on thirdweb.com.

**Soulbound caveat:** thirdweb NFT Drop is transferable by default. For same-day soulbound, prefer this Foundry contract, or use a thirdweb soulbound/non-transferable template if available and document that choice for tech.

## License

MIT
