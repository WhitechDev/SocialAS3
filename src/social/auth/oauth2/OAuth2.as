package social.auth.oauth2
{
	import org.osflash.signals.Signal;
	
	import social.auth.IAuth;
	import social.core.IUrlProvider;
	import social.gateway.IGateway;
	import social.web.IWebView;
	
	
	public class OAuth2 implements IAuth, IGateway
	{
		public static const URL_ACCESS_TOKEN			:String		= "${accessToken}";
		public static const TOKEN_SEARCHER				:RegExp		= /access_token=([\d\w\.\-_]*)/;
		
		public static const ERROR_SEARCHER_PATTERN		:RegExp		= /error=([\d\w\.\-_]*)/;
		public static const ERROR_SEARCHER				:Function	= function(url:String):Boolean{
			return ERROR_SEARCHER_PATTERN.exec(url)!=null;
		}
		
		public function get accessTokenChanged():Signal{
			if(!_accessTokenChanged)_accessTokenChanged = new Signal();
			return _accessTokenChanged;
		}
		
		private var _urlProvider			:IUrlProvider;
		
		private var _tokenSearcher			:RegExp;
		private var _errorSearcher			:Function;
		private var _accessToken			:String;
		private var _accessTokenChanged		:Signal;
		
		private var _webView				:IWebView;
		
		private var _urlScopeChecker		:Function;
		
		private var _pendingAuth			:Boolean;
		private var _onCompletes			:Array;
		private var _tokenTested			:Boolean;
		private var _showImmediately:Boolean;
		
		
		public function OAuth2(urlScopeChecker:Function, tokenSearcher:RegExp=null, errorSearcher:Function=null)
		{
			_urlScopeChecker = urlScopeChecker;
			_tokenSearcher = tokenSearcher || TOKEN_SEARCHER;
			_errorSearcher = errorSearcher || ERROR_SEARCHER;
			_onCompletes = [];
		}
		public function setWebView(webView:IWebView):void{
			_webView = webView;
		}
		public function buildUrl( urlProvider:IUrlProvider, args:Object, protocol:String ):String{
			return urlProvider.url;
		}
		public function doRequest( urlProvider:IUrlProvider, args:Object, protocol:String, onComplete:Function=null ):void
		{
			if(onComplete!=null)_onCompletes.push(onComplete);
			
			if(_urlProvider){
				_urlProvider.urlChanged.remove(onUrlChanged);
			}
			_urlProvider = urlProvider;
			_urlProvider.urlChanged.add(onUrlChanged);
			
			authenticate(args.showImmediately!=false);
			
		}
		
		private function onUrlChanged():void
		{
			authenticate(false); 
		}
		
		/**
		 * 
		 * 
		 */		
		private function authenticate(showImmediately:Boolean):void
		{
			if(!_webView || !_urlProvider || _pendingAuth)return;
			
			var url:String = _urlProvider.url
			if(!url)return;
			
			_pendingAuth = true;
			_showImmediately = showImmediately;
			
			trace("oauth2 - "+url);
			_webView.loadComplete.add(onLoadComplete);
			_webView.locationChanged.add(onLocationChanged);
			_webView.load(url, true);
			if(_showImmediately)_webView.shown = true;
		}
		public function cancelAuth():void
		{
			/*if(_accessToken){
				_accessToken = null;
				if(_accessTokenChanged)_accessTokenChanged.dispatch();
			}*/
			if(!_pendingAuth)return;
			cleanupAuth();
			callComplete(null, true);
		}
		
		private function callComplete(success:*, fail:*):void
		{
			if(_onCompletes.length){
				for each(var onComplete:Function in _onCompletes){
					onComplete(success, fail);
				}
				_onCompletes = [];
			}
		}
		
		private function onLoadComplete( success:*, fail:Boolean):void
		{
			if(success){
				checkLocation();
			}else{
				cancelAuth();
			}
		}
		
		private function onLocationChanged(cancelHandler:Function):void
		{
			checkLocation(cancelHandler);
		}
		
		private function checkLocation(cancelHandler:Function=null):void
		{
			if(!_pendingAuth)return;
			
			var location:String = _webView.location;
			
			/* 
			Sometimes FB doesn't URL encode a query string (which is itself a URL),
			this can trick the cancel search into thinking that login was cancelled.
			This sucks because there is no way of knowing when the inner URL ends and the parent
			URL continues listing it's query string, so all query string args afterwards
			are considered part of the inner URL.
			*/
			var qIndex:int = location.indexOf("?");
			if((qIndex = location.indexOf("?", qIndex+1))!=-1){
				var begInd:int = location.lastIndexOf("=", qIndex)+1;
				location = location.substr(0, begInd) + encodeURIComponent(location.substr(begInd));
			}
			
			var newToken:String;
			var res:Object = _tokenSearcher.exec(location);
			if(res){
				newToken = res[1];
			}
			if ( newToken )
			{
				_tokenTested = true;
				_accessToken = newToken;
				if(_accessTokenChanged)_accessTokenChanged.dispatch();
				cleanupAuth();
				callComplete(true, null);
			}else{
				if(_errorSearcher(location) || _urlScopeChecker==null){
					cancelAuth();
				}
				else if(!_urlScopeChecker(location)){
					if(cancelHandler!=null){
						cancelHandler();
					}else{
						_webView.load(_urlProvider.url, true);
						_webView.shown = _showImmediately;
					}
				}else{
					_webView.shown = true;
				}
			}
		}
		
		private function cleanupAuth():void
		{
			_webView.loadComplete.remove(onLoadComplete);
			_webView.locationChanged.remove(onLocationChanged);
			_pendingAuth = false;
			_webView.clearView();
		}
		
		public function markTokenWorks():void
		{
			_tokenTested = true;
		}
			
		public function get accessToken():String
		{
			return _accessToken;
		}
		
		public function set accessToken(value:String):void
		{
			_accessToken = value;
			_tokenTested = false;
			if(_accessTokenChanged)_accessTokenChanged.dispatch();
		}
		
		public function get pendingAuth():Boolean
		{
			return _pendingAuth;
		}
		
		public function get tokenTested():Boolean
		{
			return _tokenTested;
		}
	}
}