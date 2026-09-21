    const CONFIG = {
      chainId: 1,
      contractAddress: "",
      usdcAddress: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      priceUsdc: 399_000_000n,
    };
    const NFT_ABI = [
      "function mint(uint256 qty)",
      "function saleActive() view returns (bool)",
      "function maxPerWallet() view returns (uint256)",
      "function totalSupply() view returns (uint256)",
      "function maxSupply() view returns (uint256)",
      "function balanceOf(address) view returns (uint256)",
      "event Minted(address indexed minter, uint256 indexed startTokenId, uint256 quantity, bool paidInUsdc)"
    ];
    const ERC20_ABI = [
      "function approve(address spender, uint256 amount) returns (bool)",
      "function allowance(address owner, address spender) view returns (uint256)",
      "function balanceOf(address) view returns (uint256)",
      "function decimals() view returns (uint8)"
    ];
    let provider, signer, account;
    const $ = (id) => document.getElementById(id);
    const statusEl = $("status");
    const connectBtn = $("connectBtn");
    const approveBtn = $("approveBtn");
    const mintBtn = $("mintBtn");
    function setStatus(msg, kind) {
      statusEl.textContent = msg;
      statusEl.className = "status" + (kind ? " " + kind : "");
    }
    function requireConfig() {
      if (!CONFIG.contractAddress || !CONFIG.contractAddress.startsWith("0x")) {
        throw new Error("Set CONFIG.contractAddress after deploy.");
      }
    }
    async function loadArt() {
      const el = $("nftArt");
      try {
        const nParts = 7;
        const parts = await Promise.all(Array.from({length: nParts}, async (_, i) => {
          const n = i + 1;
          const r = await fetch("./fcore.mp4.b64.part" + n, { cache: "no-store" });
          if (!r.ok) throw new Error("part " + n);
          return (await r.text()).trim();
        }));
        const b64 = parts.join("");
        const bin = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
        const url = URL.createObjectURL(new Blob([bin], { type: "video/mp4" }));
        el.src = url;
        el.poster = "";
        const play = el.play();
        if (play && play.catch) play.catch(() => {});
      } catch (e) {
        console.warn("art load failed", e);
      }
    }
    async function ensureChain() {
      const hex = "0x" + CONFIG.chainId.toString(16);
      try {
        await provider.send("wallet_switchEthereumChain", [{ chainId: hex }]);
      } catch (e) {
        if (e.code === 4902 && CONFIG.chainId === 11155111) {
          await provider.send("wallet_addEthereumChain", [{
            chainId: hex,
            chainName: "Sepolia",
            nativeCurrency: { name: "SepoliaETH", symbol: "ETH", decimals: 18 },
            rpcUrls: ["https://rpc.sepolia.org"],
            blockExplorerUrls: ["https://sepolia.etherscan.io"]
          }]);
        } else { throw e; }
      }
    }
    async function connect() {
      if (!window.ethereum) {
        setStatus("No wallet found. Install MetaMask or another EIP-1193 wallet.", "err");
        return;
      }
      try {
        provider = new ethers.BrowserProvider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        await ensureChain();
        signer = await provider.getSigner();
        account = await signer.getAddress();
        const net = await provider.getNetwork();
        $("netLabel").textContent = net.name + " (" + net.chainId + ")";
        $("addrLabel").textContent = CONFIG.contractAddress || "(set after deploy)";
        connectBtn.textContent = account.slice(0, 6) + "…" + account.slice(-4);
        approveBtn.disabled = false;
        mintBtn.disabled = false;
        setStatus("Connected. Approve USDC, then mint your Core Node.", "ok");
      } catch (e) {
        setStatus(e.message || String(e), "err");
      }
    }
    async function approveUsdc() {
      try {
        requireConfig();
        const qty = BigInt($("qty").value || "1");
        if (qty < 1n || qty > 10n) throw new Error("Quantity must be 1–10.");
        const usdc = new ethers.Contract(CONFIG.usdcAddress, ERC20_ABI, signer);
        const amount = CONFIG.priceUsdc * qty;
        setStatus("Confirm USDC approve in your wallet…");
        const tx = await usdc.approve(CONFIG.contractAddress, amount);
        setStatus("Approve submitted: " + tx.hash + "\nWaiting…");
        await tx.wait();
        setStatus("USDC approved for " + qty.toString() + " node(s). You can mint now.", "ok");
      } catch (e) {
        setStatus(e.shortMessage || e.message || String(e), "err");
      }
    }
    async function mint() {
      try {
        requireConfig();
        const qty = BigInt($("qty").value || "1");
        if (qty < 1n || qty > 10n) throw new Error("Quantity must be 1–10.");
        const nft = new ethers.Contract(CONFIG.contractAddress, NFT_ABI, signer);
        const active = await nft.saleActive();
        if (!active) throw new Error("Sale is not active yet.");
        setStatus("Confirm mint in your wallet…");
        const tx = await nft.mint(qty);
        setStatus("Mint submitted: " + tx.hash + "\nWaiting for confirmation…");
        const receipt = await tx.wait();
        let ids = [];
        for (const log of receipt.logs) {
          try {
            const parsed = nft.interface.parseLog(log);
            if (parsed && parsed.name === "Minted") {
              const start = parsed.args.startTokenId;
              const q = parsed.args.quantity;
              for (let i = 0n; i < q; i++) ids.push((start + i).toString());
            }
          } catch (_) {}
        }
        setStatus(
          "Success! Minted token id(s): " + (ids.length ? ids.join(", ") : "(see explorer)") +
          "\nTx: " + tx.hash,
          "ok"
        );
      } catch (e) {
        setStatus(e.shortMessage || e.message || String(e), "err");
      }
    }
    loadArt();
    connectBtn.addEventListener("click", connect);
    approveBtn.addEventListener("click", approveUsdc);
    mintBtn.addEventListener("click", mint);
    $("addrLabel").textContent = CONFIG.contractAddress || "not configured";
