package org.perl.inline.java ;

import java.io.* ;
import java.net.* ;
import java.util.* ;


class InlineJavaServerThread extends Thread {
	private InlineJavaServer ijs ;
	private Socket client ;
	private BufferedReader br ;
	private BufferedWriter bw ;
	private InlineJavaUserClassLoader ijucl ;


	InlineJavaServerThread(String name, InlineJavaServer _ijs, Socket _client, InlineJavaUserClassLoader _ijucl) throws IOException {
		super(name) ;
		client = _client ;
		ijs = _ijs ;
		ijucl = _ijucl ;

		br = new BufferedReader(
			new InputStreamReader(client.getInputStream())) ;
		bw = new BufferedWriter(
			new OutputStreamWriter(client.getOutputStream())) ;

		String security_type = br.readLine() ;
		if (security_type.equals("private")){
			ijucl = new InlineJavaUserClassLoader() ;
		}
	}


	BufferedReader GetReader(){
		return br ;
	}


	BufferedWriter GetWriter(){
		return bw ;
	}


	InlineJavaUserClassLoader GetUserClassLoader(){
		return ijucl ;
	}


	public void run(){
		try {
			ijs.AddThread(this) ;

			while (true){
				String cmd = br.readLine() ;

				String resp = ijs.ProcessCommand(cmd) ;
				if (resp != null){
					bw.write(resp) ;
					bw.flush() ;
				}
				else {
					break ;
				}
			}
		}
		catch (IOException e){
			System.err.println("IO error: " + e.getMessage()) ;
		}
		finally {
			ijs.RemoveThread(this) ;
		}
	}
}
