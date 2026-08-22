import { createReadStream } from "node:fs";
import { access, stat } from "node:fs/promises";
import { extname, join, relative, resolve, sep } from "node:path";

const siteDirectory = resolve(process.argv[2] ?? "docs");
const port = Number.parseInt(process.argv[3] ?? "4321", 10);
const hostingBasePath = process.env.SITE_BASE_PATH ?? "";

if (!Number.isInteger(port) || port < 1 || port > 65_535) {
    throw new Error("The preview port must be an integer between 1 and 65535.");
}

const contentTypes = {
    ".css": "text/css; charset=utf-8",
    ".html": "text/html; charset=utf-8",
    ".ico": "image/x-icon",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".js": "text/javascript; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".webp": "image/webp",
    ".woff": "font/woff",
    ".woff2": "font/woff2"
};

function isWithinSiteDirectory(candidate) {
    const candidateRelativePath = relative(siteDirectory, candidate);
    return candidateRelativePath === "" || (!candidateRelativePath.startsWith(`..${sep}`) && candidateRelativePath !== "..");
}

async function existingFile(candidate) {
    try {
        const candidateStatus = await stat(candidate);
        if (candidateStatus.isFile()) return candidate;
        if (candidateStatus.isDirectory()) return existingFile(join(candidate, "index.html"));
    } catch {}
}

async function resolveFile(pathname) {
    const pathWithoutBase = hostingBasePath && pathname.startsWith(hostingBasePath)
        ? pathname.slice(hostingBasePath.length) || "/"
        : pathname;
    const candidate = resolve(siteDirectory, decodeURIComponent(pathWithoutBase).replace(/^\//, ""));
    return isWithinSiteDirectory(candidate) ? existingFile(candidate) : undefined;
}

await access(siteDirectory);

createServer(async (request, response) => {
    try {
        const file = await resolveFile(new URL(request.url ?? "/", "http://localhost").pathname);
        if (!file) {
            response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
            response.end("Not found\n");
            return;
        }
        response.writeHead(200, { "Content-Type": contentTypes[extname(file).toLowerCase()] ?? "application/octet-stream" });
        createReadStream(file).pipe(response);
    } catch (error) {
        response.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
        response.end(`Preview server error: ${error.message}\n`);
    }
}).listen(port, "127.0.0.1", () => {
    console.log(`Previewing ${siteDirectory} at http://127.0.0.1:${port}${hostingBasePath}/`);
});
