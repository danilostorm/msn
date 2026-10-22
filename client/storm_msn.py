# Storm MSN independent Tkinter GUI client.
import asyncio
import queue
import threading
import tkinter as tk
from tkinter import ttk, messagebox, simpledialog
from msnp7 import Protocol


class App:
    def __init__(self):
        self.root=tk.Tk()
        self.root.title("Storm MSN • Messenger")
        self.root.geometry("450x650")
        self.root.configure(bg="#def1fb")
        self.events=queue.Queue()
        self.contacts={}
        self.presence={}
        self.chats={}
        self.proto=None
        self.loop=None
        self.login_screen()
        self.root.after(80,self.pump)
        self.root.protocol("WM_DELETE_WINDOW",self.quit)
    def clear(self):
        for w in self.root.winfo_children():w.destroy()
    def login_screen(self):
        self.clear()
        box=tk.Frame(self.root,bg="#def1fb",padx=40,pady=35)
        box.pack(fill="both",expand=True)
        tk.Label(box,text="🟢 Storm MSN",bg="#def1fb",fg="#097cab",font=("Segoe UI",26,"bold")).pack(pady=25)
        tk.Label(box,text="O seu Messenger está de volta!",bg="#def1fb",fg="#5985a0").pack(pady=5)
        self.inputs=[]
        for name,initial,hide in [("Servidor","msn.hoststorm.com.br",False),("E-mail","",False),("Senha","",True)]:
            tk.Label(box,text=name,bg="#def1fb",fg="#336d8d",font=("Segoe UI",10,"bold")).pack(anchor="w",pady=(20,5))
            e=ttk.Entry(box,show="●" if hide else "")
            e.pack(fill="x",ipady=7)
            e.insert(0,initial)
            self.inputs.append(e)
        ttk.Button(box,text="Entrar no MSN",command=self.connect).pack(fill="x",pady=30,ipady=7)
        tk.Label(box,text="MSNP7 usa autenticação antiga e mensagens sem criptografia.\nNão reutilize senhas de outros serviços.",bg="#def1fb",fg="#a26c65",justify="center").pack()
    def connect(self):
        host,email,pw=(e.get().strip() for e in self.inputs)
        if not (host and "@" in email and pw):return messagebox.showwarning("Storm MSN","Preencha servidor, e-mail e senha.")
        self.inputs[2].delete(0,"end")
        self.proto=Protocol(host,email,pw,self.events)
        self.loop=asyncio.new_event_loop()
        def runner():
            asyncio.set_event_loop(self.loop)
            self.loop.run_until_complete(self.proto.login())
        threading.Thread(target=runner,daemon=True).start()
    def submit(self,coro):
        if self.loop and self.loop.is_running():
            f=asyncio.run_coroutine_threadsafe(coro,self.loop)
            f.add_done_callback(lambda f:self.events.put(("error",str(f.exception()))) if f.exception() else None)
        else:coro.close()
    def online(self,email):
        self.clear()
        head=tk.Frame(self.root,bg="#29a7d3",padx=20,pady=20);head.pack(fill="x")
        tk.Label(head,text="🟢 Storm MSN",bg="#29a7d3",fg="white",font=("Segoe UI",20,"bold")).pack(anchor="w")
        tk.Label(head,text=email,bg="#29a7d3",fg="white").pack(anchor="w")
        bar=tk.Frame(self.root,bg="#def1fb",padx=14,pady=12);bar.pack(fill="x")
        self.status=ttk.Combobox(bar,values=["Online","Ocupado","Ausente","Invisível"],width=14,state="readonly")
        self.status.current(0);self.status.pack(side="left")
        self.status.bind("<<ComboboxSelected>>",lambda ev:self.submit(self.proto.change({"Online":"NLN","Ocupado":"BSY","Ausente":"AWY","Invisível":"HDN"}[self.status.get()])))
        ttk.Button(bar,text="Adicionar amigo",command=self.add).pack(side="right")
        self.listbox=tk.Listbox(self.root,font=("Segoe UI",11),bg="white",fg="#2b6585",relief="flat")
        self.listbox.pack(fill="both",expand=True,padx=14,pady=14)
        self.listbox.bind("<Double-Button-1>",self.open_selected)
        ttk.Button(self.root,text="Conversar",command=self.open_selected).pack(fill="x",padx=14,pady=(0,12))
    def refresh(self):
        self.listbox.delete(0,"end")
        for email in sorted(self.contacts):
            dot="🟢" if self.presence.get(email)=="online" else "⚪"
            self.listbox.insert("end",f"{dot} {email}")
    def add(self):
        email=simpledialog.askstring("Storm MSN","E-mail do seu amigo:",parent=self.root)
        if email and "@" in email:self.submit(self.proto.add(email.strip().lower()))
    def open_selected(self,event=None):
        s=self.listbox.curselection()
        if s:self.open_chat(sorted(self.contacts)[s[0]])
    def open_chat(self,email):
        if email in self.chats and self.chats[email][0].winfo_exists():
            self.chats[email][0].lift();return
        win=tk.Toplevel(self.root);win.title("Storm MSN • "+email);win.geometry("530x460")
        log=tk.Text(win,state="disabled",wrap="word",font=("Segoe UI",11))
        log.pack(fill="both",expand=True,padx=10,pady=10)
        bottom=tk.Frame(win);bottom.pack(fill="x",padx=10,pady=(0,10))
        entry=ttk.Entry(bottom);entry.pack(side="left",fill="x",expand=True)
        def send():
            text=entry.get().strip()
            if not text:return
            entry.delete(0,"end")
            self.append(email,"Você: "+text)
            self.submit(self.proto.send_message(email,text))
        ttk.Button(bottom,text="Enviar",command=send).pack(side="right")
        entry.bind("<Return>",lambda event:send())
        self.chats[email]=(win,log)
    def append(self,email,text):
        if email not in self.chats:self.open_chat(email)
        log=self.chats[email][1];log.config(state="normal")
        log.insert("end",text+"\n");log.see("end");log.config(state="disabled")
    def pump(self):
        for _ in range(40):
            try:ev=self.events.get_nowait()
            except queue.Empty:break
            kind,*args=ev
            if kind=="online":self.online(args[0])
            elif kind=="contact" and "@" in args[0]:
                self.contacts[args[0]]=args[1];self.refresh()
            elif kind=="presence":
                self.presence[args[0]]=args[1];self.refresh()
            elif kind=="message":
                self.append(args[0],args[0]+": "+args[1]);self.root.bell()
            elif kind=="ready":self.submit(self.proto.flush(args[0]))
            elif kind=="error":
                if args[0]:messagebox.showwarning("Storm MSN",args[0])
        self.root.after(80,self.pump)
    def quit(self):
        if self.proto:self.submit(self.proto.disconnect())
        self.root.destroy()
    def run(self):self.root.mainloop()

if __name__=="__main__":App().run()
