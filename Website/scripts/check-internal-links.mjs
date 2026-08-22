import { access, readdir, readFile, stat } from "node:fs/promises";
import { join, relative, resolve, sep } from "node:path";

const outputDirectory = resolve(process.argv[2] ?? "dist");
const hostingBasePath = (process.env.SITE_BASE_PATH ?? "/roundtrip-swift").replace(/\/$/, "");
const attributePattern = /\b(?:href|src)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))/gi;
const htmlFiles = [];
const failures = [];

async function collectHTMLFiles(directory) {
    for (const entry of await readdir(directory, { withFileTypes: true })) {
        const entryPath = join(directory, entry.name);
        if (entry.isDirectory()) await collectHTMLFiles(entryPath);
        if (entry.isFile() && entry.name.endsWith(".html")) htmlFiles.push(entryPath);
    }
}

function isExternal(reference) {
    return reference.startsWith("#") || reference.startsWith("//") || /^[a-z][a-z0-9+.-]*:/i.test(reference);
}

function isWithinOutputDirectory(candidate) {
    const candidateRelativePath = relative(outputDirectory, candidate);
    return candidateRelativePath === "" || (!candidateRelativePath.startsWith(`..${sep}`) && candidateRelativePath !== "..");
}

async function resolvesToSiteContent(sourceFile, reference) {
    let referencePath = decodeURIComponent(reference.split(/[?#]/, 1)[0]);
    if (referencePath.startsWith("/")) {
        if (hostingBasePath && !referencePath.startsWith(`${hostingBasePath}/`) && referencePath !== hostingBasePath) return false;
        referencePath = hostingBasePath ? referencePath.slice(hostingBasePath.length) : referencePath;
    } else {
        referencePath = join(relative(outputDirectory, resolve(sourceFile, "..")), referencePath);
    }
    const candidate = resolve(outputDirectory, referencePath.replace(/^\//, ""));
    if (!isWithinOutputDirectory(candidate)) return false;
    try {
        const candidateStatus = await stat(candidate);
        if (candidateStatus.isFile()) return true;
        return candidateStatus.isDirectory() && (await stat(join(candidate, "index.html"))).isFile();
    } catch {
        return false;
    }
}

await access(outputDirectory);
await collectHTMLFiles(outputDirectory);
for (const sourceFile of htmlFiles) {
    const source = await readFile(sourceFile, "utf8");
    for (const match of source.matchAll(attributePattern)) {
        const reference = match[1] ?? match[2] ?? match[3];
        if (reference && !isExternal(reference) && !(await resolvesToSiteContent(sourceFile, reference))) {
            failures.push(`${relative(outputDirectory, sourceFile)} -> ${reference}`);
        }
    }
}

if (failures.length > 0) {
    console.error("Broken internal links:");
    for (const failure of failures) console.error(`  ${failure}`);
    process.exitCode = 1;
} else {
    console.log(`Checked ${htmlFiles.length} HTML files in ${outputDirectory}.`);
}
