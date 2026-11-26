# guiplatforms.py - the IDE page: every platform in the list is in the library and compiles.
#   python3 test/guiplatforms.py hosted/ntc.html   (or src/ntc.html)
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, asyncio, sys
from playwright.async_api import async_playwright
async def main():
    page = sys.argv[1]
    async with async_playwright() as p:
        b = await p.chromium.launch(); pg = await b.new_page(viewport={'width':1500,'height':850})
        errs=[]; pg.on('pageerror', lambda e: errs.append(str(e))); pg.on('dialog', lambda d: asyncio.ensure_future(d.accept()))
        await pg.goto('file://'+os.path.abspath(page)); await pg.wait_for_timeout(1000)
        vals = await pg.eval_on_selector_all('#ge-platform option','o=>o.map(x=>x.value)')
        lib = await pg.evaluate('Object.keys(NTC_PLATFORMS)')
        print('options',len(vals),'library platforms',len(lib),'missing from list',[x for x in lib if x not in vals],'not in library',[x for x in vals if x not in lib])
        for v in vals:
            await pg.select_option('#ge-platform', v); await pg.wait_for_timeout(500)
            out = await pg.evaluate('m_strAsm'); er = (await pg.locator('#ge-errors').inner_text()).strip()
            print('%-13s asm %7d bytes  errors: %s' % (v, len(out or ''), er[:70] or '-'))
        print('page errors', errs)
        await b.close()
asyncio.run(main())
