NTC BASIC - the hosted page

Upload everything in this folder to a folder on a web server (any static host).
On Apache, rename htaccess to .htaccess: it stops directory listings.
Then open the folder's address (index.html opens ntc.html).

Nothing runs on the server. The page is HTML, JavaScript and CSS: it compiles in the
visitor's browser, opens and saves files on their own PC (and keeps the project they
are working on in their browser's local storage). Assembling the .asm is done on their
PC with sjasmplus, as with the page run from NTC's src/ folder.

Made by NTC's tools/hosted/build.js from src/ - run it again after changing the page.

(c) 2026 Cyborg Unicorn Pty Ltd - https://cyborgunicorn.com.au
