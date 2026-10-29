<#
.SYNOPSIS
  Gera a versão publicada da aplicação, protegida por senha.

.DESCRIPTION
  Criptografa o index.html com AES-256-GCM, usando uma chave derivada da senha por
  PBKDF2-SHA256, insere o resultado na tela de acesso (template/entrada.html) e grava a
  versão protegida na pasta "publicar". Também exibe o valor de ACESSO_HASH, usado pela
  função de servidor para validar o acesso aos dados compartilhados.
  A senha não é armazenada em nenhum arquivo.

.EXAMPLE
  pwsh tools/publicar.ps1 -Senha "********"
#>
param(
  [Parameter(Mandatory = $true)][string]$Senha,
  [string]$Origem = "",
  [string]$PastaPublicacao = ""
)
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $PSScriptRoot 'config.json'
if (-not $Origem) { $Origem = Join-Path $raiz 'index.html' }
if (-not $PastaPublicacao) { $PastaPublicacao = Join-Path $raiz 'publicar' }

# Salt fixo entre publicações (não é segredo). Mantê-lo preserva o "Lembrar neste computador".
if (Test-Path $configPath) {
  $config = Get-Content $configPath -Raw | ConvertFrom-Json
} else {
  $saltBytes = [byte[]]::new(16); [System.Security.Cryptography.RandomNumberGenerator]::Fill($saltBytes)
  $config = [pscustomobject]@{ salt = [Convert]::ToBase64String($saltBytes); iteracoes = 600000 }
  $config | ConvertTo-Json | Set-Content $configPath -Encoding utf8NoBOM
}

$texto = [System.IO.File]::ReadAllBytes($Origem)
$salt  = [Convert]::FromBase64String($config.salt)
$chave = [System.Security.Cryptography.Rfc2898DeriveBytes]::Pbkdf2(
           [System.Text.Encoding]::UTF8.GetBytes($Senha), $salt, [int]$config.iteracoes,
           [System.Security.Cryptography.HashAlgorithmName]::SHA256, 32)

$iv = [byte[]]::new(12); [System.Security.Cryptography.RandomNumberGenerator]::Fill($iv)
$cifra = [byte[]]::new($texto.Length)
$tag   = [byte[]]::new(16)
$aes = [System.Security.Cryptography.AesGcm]::new($chave, 16)
$aes.Encrypt($iv, $texto, $cifra, $tag)
$aes.Dispose()

# O Web Crypto espera o texto cifrado seguido da etiqueta de autenticação.
$dados = [byte[]]::new($cifra.Length + $tag.Length)
[Array]::Copy($cifra, 0, $dados, 0, $cifra.Length)
[Array]::Copy($tag, 0, $dados, $cifra.Length, $tag.Length)

$modelo = Get-Content (Join-Path $raiz 'template\entrada.html') -Raw -Encoding utf8
$saida = $modelo.Replace('__ITER__', [string]$config.iteracoes).
                 Replace('__SALT__', $config.salt).
                 Replace('__IV__', [Convert]::ToBase64String($iv)).
                 Replace('__DADOS__', [Convert]::ToBase64String($dados))

New-Item -ItemType Directory -Force $PastaPublicacao | Out-Null
[System.IO.File]::WriteAllText((Join-Path $PastaPublicacao 'index.html'), $saida, [System.Text.UTF8Encoding]::new($false))
Write-Output ("Versão protegida gerada em {0} ({1:N0} bytes)." -f $PastaPublicacao, $saida.Length)

# Código de verificação do acesso aos dados compartilhados (variável ACESSO_HASH no Netlify).
# Mesma derivação feita no navegador: HKDF-SHA256 sobre a chave da senha, info "acesso".
$token = [System.Security.Cryptography.HKDF]::DeriveKey(
           [System.Security.Cryptography.HashAlgorithmName]::SHA256, $chave, 32,
           [System.Text.Encoding]::UTF8.GetBytes('fechamento-comissoes'),
           [System.Text.Encoding]::UTF8.GetBytes('acesso'))
$hash = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($token)).ToLower()
Write-Output "ACESSO_HASH=$hash"
