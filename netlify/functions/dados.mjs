// Armazena e devolve os dados compartilhados do fechamento.
// O conteúdo chega criptografado pelo navegador; o servidor nunca recebe a senha
// nem os dados em texto aberto. O acesso é validado pelo código derivado da senha,
// comparado com o hash configurado na variável de ambiente ACESSO_HASH.
import { getStore } from "@netlify/blobs";
import { createHash, timingSafeEqual } from "node:crypto";

const LIMITE_CONTEUDO = 5 * 1024 * 1024; // 5 MB em base64

function autorizado(req) {
  const esperado = Buffer.from(process.env.ACESSO_HASH || "", "hex");
  const token = req.headers.get("x-acesso") || "";
  if (esperado.length !== 32 || !token) return false;
  const recebido = createHash("sha256").update(Buffer.from(token, "base64")).digest();
  return timingSafeEqual(recebido, esperado);
}

const json = (corpo, status = 200) =>
  new Response(JSON.stringify(corpo), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });

export default async (req) => {
  if (!autorizado(req)) return json({ erro: "acesso" }, 401);
  const store = getStore({ name: "fechamento", consistency: "strong" });

  if (req.method === "GET") {
    const atual = await store.get("estado", { type: "json" });
    return json(atual || { versao: 0 });
  }

  if (req.method === "PUT") {
    let corpo;
    try { corpo = await req.json(); } catch { return json({ erro: "formato" }, 400); }
    const { iv, conteudo, versaoBase, forcar } = corpo || {};
    if (typeof iv !== "string" || iv.length > 64 || typeof conteudo !== "string" ||
        !conteudo || conteudo.length > LIMITE_CONTEUDO || !Number.isInteger(versaoBase)) {
      return json({ erro: "formato" }, 400);
    }
    const atual = await store.get("estado", { type: "json" });
    const versaoAtual = atual?.versao || 0;
    if (versaoBase !== versaoAtual && forcar !== true) {
      return json({ erro: "conflito", versao: versaoAtual, atualizadoEm: atual?.atualizadoEm }, 409);
    }
    const novo = { versao: versaoAtual + 1, iv, conteudo, atualizadoEm: new Date().toISOString() };
    await store.setJSON("estado", novo);
    await store.setJSON(`historico/${String(novo.versao).padStart(6, "0")}`, novo); // permite recuperar versões anteriores
    return json({ versao: novo.versao, atualizadoEm: novo.atualizadoEm });
  }

  return json({ erro: "metodo" }, 405);
};

export const config = { path: "/api/dados" };
