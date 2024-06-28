import gleam/result
import gleam/string
import simplifile
import tom

pub fn main() {
  // 1. Get the app name
  let assert Ok(app_name) = get_app_name()

  // 2. Make scripts folder
  let _ = simplifile.create_directory("scripts")

  // 3. Make styles folder
  let _ = simplifile.create_directory("src/styles")
  make_styles_template("src/styles/app.scss")

  // 3. Make scripts
  make_compile_script("scripts/compile.js")
  make_build_script("scripts/build.js")
  make_watch_script("scripts/watch.js")
  make_server_script("scripts/server.ts")

  // 4. Make output folders
  let _ = simplifile.create_directory_all("priv/static/css")
  let _ = simplifile.create_directory_all("priv/static/js")

  // 5. Make output files
  make_entry_file("priv/static/js/entry.mjs", app_name)
  make_html_file("priv/static/index.html", app_name)
  make_package_json_file("package.json")
}

fn get_app_name() -> Result(String, Nil) {
  use config <- result.try(
    simplifile.read(from: "gleam.toml") |> result.map_error(fn(_) { Nil }),
  )
  use parsed <- result.try(tom.parse(config) |> result.map_error(fn(_) { Nil }))
  use app_name <- result.try(
    tom.get_string(parsed, ["name"]) |> result.map_error(fn(_) { Nil }),
  )
  Ok(app_name)
}

fn make_styles_template(filepath: String) {
  let _ =
    "

    "
    |> simplifile.write(to: filepath, contents: _)
  Nil
}

fn make_entry_file(filepath: String, app_name: String) {
  let _ =
    "
import { main } from './{app_name}.mjs';

main();
"
    |> string.replace("{app_name}", app_name)
    |> simplifile.write(to: filepath, contents: _)
  Nil
}

fn make_package_json_file(filepath: String) {
  let _ =
    "
{
  \"type\": \"module\",
  \"scripts\": {
    \"build\": \"node scripts/build.js\",
    \"watch\": \"node scripts/watch.js\"
  },
  \"devDependencies\": {
    \"chokidar\": \"^3.6.0\",
    \"deno\": \"^0.1.1\",
    \"esbuild\": \"^0.21.5\",
    \"esbuild-sass-plugin\": \"^3.3.1\",
    \"toml\": \"^3.0.0\"
  }
}
"
    |> simplifile.write(to: filepath, contents: _)
  Nil
}

fn make_html_file(filepath: String, app_name: String) {
  let _ =
    "
<!doctype html>
<html lang='en'>
  <head>
    <meta charset='utf-8' />
    <meta name='viewport' content='width=device-width, initial-scale=1.0' />

    <title>🚧 {app_name}</title>

    <link rel='stylesheet' href='/priv/static/{app_name}.css'>
    <script type='module' src='/priv/static/entry.mjs'></script>
  </head>

  <body>
    <div id='app'></div>
  </body>
</html>
    "
    |> string.replace("{app_name}", app_name)
    |> simplifile.write(to: filepath, contents: _)
  Nil
}

fn make_compile_script(filepath: String) {
  let _ =
    "
import { exec } from 'child_process';

async function compile() {
	return new Promise((resolve, reject) => {
		exec('gleam build', (error, stdout, stderr) => {
			if (error) {
				console.error(`Error: ${error.message}`);
				reject(error);
				return;
			}
			if (stderr) {
				console.error(`stderr: ${stderr}`);
				reject(new Error(stderr));
				return;
			}
			console.log(`stdout: ${stdout}`);
			resolve(stdout);
		});
	});
}
export default compile;
"
    |> simplifile.write(to: filepath, contents: _)
  Nil
}

fn make_build_script(filepath: String) {
  let _ =
    "
import esbuild from 'esbuild';
import { sassPlugin } from 'esbuild-sass-plugin';
import path from 'path';
import fs from 'fs';
import toml from 'toml';
import compile from './compile.js';
import { promises as fsPromises } from 'fs';

async function readConfig() {
	const configContent = await fsPromises.readFile('gleam.toml', 'utf-8');
	return toml.parse(configContent);
}

async function build() {
	try {
		const config = await readConfig();
		const appName = config.name;
		const env = config.env || 'dev';
		const jsInputFile = `build/${env}/javascript/${appName}/${appName}.mjs`;
		const cssInputFile = 'src/styles/app.scss';
		const outputDir = 'priv/static';
		const jsOutputFile = path.join(outputDir, 'js', `${appName}.mjs`);
		const cssOutputFile = path.join(outputDir, 'css', `${appName}.css`);

		await compile();

		// Build Javascript
		await esbuild.build({
			entryPoints: [jsInputFile],
			bundle: true,
			minify: false,
			outfile: jsOutputFile,
			format: 'esm',
			loader: {
				'.mjs': 'js',
			}
		});

		// Build CSS
		await esbuild.build({
			entryPoints: [cssInputFile],
			bundle: true,
			minify: true,
			outfile: cssOutputFile,
			plugins: [
				sassPlugin(),
			]
		});

		const htmlSource = path.resolve('src/index.html');
		const htmlDest = path.resolve(outputDir, 'index.html');
		if (fs.existsSync(htmlSource)) {
			fs.copyFileSync(htmlSource, htmlDest);
		}
		console.log('Build complete');

	} catch (error) {
		console.error('Build failed:', error);
	}
}

build().catch(() => process.exit(1));

export default build;
    "
    |> simplifile.write(to: filepath, contents: _)
  Nil
}

fn make_watch_script(filepath: String) {
  let _ =
    "
import chokidar from 'chokidar';
import build from './build.js';
import { exec } from 'child_process';

async function startWatching() {

	const watcher = chokidar.watch(['src/**/*.gleam', 'src/styles/**/*.scss', 'src/styles/**/*.css', 'src/index.html'], {
		persistent: true
	});

	watcher.on('change', async (path) => {
		console.log(`File changed: ${path}`);
		try {
			await build();
		} catch (error) {
			console.error('Error during build:', error);
		}
	});

	console.log('Watching for changes...');

	exec('deno run --allow-read=. --allow-net scripts/server.ts', (error, stdout, stderr) => {
		if (error) {
			console.error(`Error starting server: ${error.message}`);
			return;
		}
		if (stderr) {
			console.error(`Server stderr: ${stderr}`);
			return;
		}
		console.log(`Server stdout: ${stdout}`);
	});
}

startWatching().catch(console.error);
    "
    |> simplifile.write(to: filepath, contents: _)
  Nil
}

fn make_server_script(filepath: String) {
  let _ =
    "import { extname } from 'https://deno.land/std/path/mod.ts'

const port = 1234;
const server = Deno.listen({ port: port });
console.log(`File server running on http://localhost:${port}/`);

for await (const conn of server) {
	handleHttp(conn).catch(console.error);
}

async function handleHttp(conn: Deno.Conn) {
	const httpConn = Deno.serveHttp(conn);
	for await (const requestEvent of httpConn) {
		// Use the request pathname as filepath
		const url = new URL(requestEvent.request.url);
		let filepath = decodeURIComponent(url.pathname);
		if (filepath === '/') {
			filepath = '/index.html';
		}

		// Try opening the file
		let file;
		try {
			file = await Deno.open('priv/static' + filepath, { read: true });
		} catch {
			// If the file cannot be opened, return a '404 Not Found' response
			const notFoundResponse = new Response('404 Not Found', { status: 404 });
			await requestEvent.respondWith(notFoundResponse);
			continue;
		}

		// Build a readable stream so the file doesn't have to be fully loaded into
		// memory while we send it
		const readableStream = file.readable;
		const contentType = getContentType(filepath);

		// Build and send the response
		const response = new Response(readableStream, {
			headers: { 'content-type': contentType },
		});
		await requestEvent.respondWith(response);
	}
}

function getContentType(filepath) {
	const ext = extname(filepath);
	switch (ext) {
		case '.html':
			return 'text/html';
		case '.mjs':
			return 'application/javascript';
		case '.js':
			return 'application/javascript';
		case '.css':
			return 'text/css';
		case '.json':
			return 'application/json';
		case '.png':
			return 'image/png';
		case '.jpg':
		case '.jpeg':
			return 'image/jpeg';
		case '.gif':
			return 'image/gif';
		case '.svg':
			return 'image/svg+xml';
		case '.ico':
			return 'image/x-icon';
		default:
			return 'application/octet-stream';
	}
}"
    |> simplifile.write(to: filepath, contents: _)
  Nil
}
