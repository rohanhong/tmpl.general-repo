# Origin remote: transport and readiness

Loaded from `repo-init/SKILL.md`. Read this file at step 6e, before settling the transport. The Hard rules in `SKILL.md` remain in force throughout.

Both transports are supported, and the transport fixes the URL form, so settle it before taking the URL.

## URL already given

Its form is the transport: `https://...` is HTTPS; `http://...` is HTTP, which sends credentials unencrypted (warn about that), and is otherwise handled like HTTPS; `git@host:...`, `host:...`, or `ssh://...` is SSH; a local path (`/c/x/r.git`, `C:/x/r.git`, `../r.git`, `r.git`) or a `file://` URL is a local remote that needs no credentials, so it gets no readiness probe. Classify it and take the host, plus the port when the URL names one:

```
sh <<'EOF'
u='<url>'
case "$u" in
  file://*|/*|.*|[A-Za-z]:*) echo "local path: no readiness probe";;
  *://*) t=${u%%://*}; h=${u#*://}; h=${h%%/*}; h=${h##*@}; p=
    case "$h" in
      \[*\]:*) p=${h##*]:}; h=${h%]:*}; h=${h#?};;
      \[*\]) h=${h%?}; h=${h#?};;
      *:*) p=${h##*:}; h=${h%:*};;
    esac
    case "$t" in https) t=HTTPS;; http) t='HTTP (unencrypted)';; ssh) t=SSH;; esac
    echo "transport: $t host: $h${p:+ port: $p}";;
  *) case "${u%%/*}" in
       *:*) h=${u%%:*}; case "$u" in \[*\]:*|*@\[*\]:*) h=${u%%]:*};; esac
         h=${h##*@}; echo "transport: SSH host: ${h#[[]}";;
       *) echo "local path: no readiness probe";;
     esac;;
esac
EOF
```

The `[A-Za-z]:*` case keeps a Windows drive path from reading as an SCP-style `host:path`, and a path with no colon before its first `/` (such as `r.git`) reads as local; both are rules git applies. A bracketed IPv6 host prints without its brackets. For SSH, run only the SSH readiness signal below, with `-p <port>` when a port was printed; for HTTPS or HTTP, only the credential-helper signal (the port plays no part). Any other printed transport (for example `git`) is outside this flow: ask the user for an HTTPS or SSH URL. Warn when the signal is not ready.

## No URL yet

Ask for the forge host as free text (for example `github.com`, `gitlab.com`, or a self-hosted name). Run these independent reads, one per readiness signal:

* `git config --get credential.helper`: any non-empty value, such as `manager`, `osxkeychain`, `libsecret`, `store`, or `cache`, means HTTPS credentials have a place to live.
* `ssh -o BatchMode=yes -o ConnectTimeout=5 -T git@<host> 2>&1` (add `-p <port>` when the URL or the user names a non-default port; `BatchMode` makes it fail fast without prompting). Exit 255 is ssh's own failure, such as `Permission denied`, `Host key verification failed`, or a timeout, and means SSH is not ready; any other exit, typically 0 or 1 with a greeting from the host, means the key authenticated. Greetings differ per host, so decide by the exit code, the same rule `git-push` uses.

Then ask with a choice question **HTTPS** / **SSH**, recommending whichever is ready; when both are, recommend neither; when neither is, recommend HTTPS, which needs only a credential helper, while SSH needs a key registered with the forge and a trusted host key. Then take the URL in the chosen form as free text.
