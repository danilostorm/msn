"""Exercise the actual Storm MSN desktop client's transport against server."""
import asyncio
import queue
import secrets
import sys
from core.conn import Conn
from core.db import User as DBUser, UserContact
from script.user import set_passwords
from util.misc import gen_uuid
import settings
sys.path.insert(0,"/app/client")
from msnp7 import Protocol

async def main():
    suffix=secrets.token_hex(5)
    emails=[f"e2e-win-a-{suffix}@test.invalid",f"e2e-win-b-{suffix}@test.invalid"]
    pw=[secrets.token_urlsafe(18),secrets.token_urlsafe(18)]
    db=Conn(settings.DB)
    with db.session() as ses:
        for i,email in enumerate(emails):
            obj=DBUser(uuid=gen_uuid(),email=email,username=f"desktop-{i}-{suffix}",verified=True,friendly_name=f"Desktop{i}",groups={},settings={})
            set_passwords(obj,pw[i],support_old_msn=True)
            ses.add(obj)
    print("TEMP_USERS_CREATED")
    tasks=[]
    try:
        q1=queue.Queue();q2=queue.Queue()
        a=Protocol("127.0.0.1",emails[0],pw[0],q1)
        b=Protocol("127.0.0.1",emails[1],pw[1],q2)
        tasks=[asyncio.create_task(a.login()),asyncio.create_task(b.login())]
        async def expect(q,kind,deadline=12):
            until=asyncio.get_running_loop().time()+deadline
            seen=[]
            while asyncio.get_running_loop().time()<until:
                try: event=q.get_nowait()
                except queue.Empty:
                    await asyncio.sleep(.05)
                    continue
                seen.append(event)
                if event[0]=="error":raise AssertionError("Client error: "+repr(event))
                if event[0]==kind:return event
            raise AssertionError("Expected "+kind+", got "+repr(seen))
        await asyncio.gather(expect(q1,"online"),expect(q2,"online"))
        print("PASS_NATIVE_CLIENT_LOGIN_X2")
        await a.send_message(emails[1],"mensagem-real-do-Storm-MSN")
        await expect(q1,"ready")
        await a.flush(emails[1])
        ev=await expect(q2,"message")
        assert "mensagem-real-do-Storm-MSN" in ev[-1],ev
        print("PASS_NATIVE_CLIENT_CHAT_MESSAGE")
    finally:
        for t in tasks:t.cancel()
        await asyncio.gather(*tasks,return_exceptions=True)
        with db.session() as ses:
            for email in emails:
                row=ses.query(DBUser).filter(DBUser.email==email).one_or_none()
                if row:
                    ses.query(UserContact).filter((UserContact.user_id==row.id)|(UserContact.contact_id==row.id)).delete(synchronize_session=False)
                    ses.delete(row)
        print("TEMP_USERS_REMOVED")

if __name__=="__main__":
    asyncio.run(main())
