package social.web
{
	import org.osflash.signals.Signal;

	public interface IWebView
	{
		function get loadComplete():Signal;    // -> (success:*, fail:*)
		function get locationChanged():Signal; // -> (cancelHandler:Function)
		
		function get isLoading():Boolean;
		function get isLoadingChanged():Signal;
		
		function get isPopulated():Boolean;
		function get isPopulatedChanged():Signal;
		
		function showView(url:String, showImmediately:Boolean, clearHistory:Boolean = false):void;
		function hideView():void;
		
		function get location():String;
	}
}