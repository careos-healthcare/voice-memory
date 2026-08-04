type ExtensionCallback<T = void> = (value: T) => void;

interface ExtensionTab {
  id?: number;
  url?: string;
  title?: string;
  windowId?: number;
}

interface ExtensionApi {
  runtime: {
    lastError?: { message?: string };
    onMessage: {
      addListener(
        listener: (
          message: unknown,
          sender: unknown,
          respond: (value: unknown) => void,
        ) => boolean | void,
      ): void;
    };
    sendMessage(message: unknown): Promise<unknown>;
  };
  storage: {
    local: {
      get(keys: string[]): Promise<Record<string, unknown>>;
      set(values: Record<string, unknown>): Promise<void>;
      remove(keys: string[]): Promise<void>;
    };
  };
  tabs: {
    query(query: Record<string, unknown>): Promise<ExtensionTab[]>;
    captureVisibleTab(
      windowId?: number,
      options?: Record<string, unknown>,
    ): Promise<string>;
  };
  scripting: {
    executeScript<T>(options: {
      target: { tabId: number };
      func: () => T;
    }): Promise<Array<{ result?: T }>>;
  };
  contextMenus: {
    create(options: Record<string, unknown>): void;
    onClicked: {
      addListener(
        listener: (
          info: { menuItemId: string | number; selectionText?: string },
          tab?: ExtensionTab,
        ) => void,
      ): void;
    };
  };
}

declare const chrome: ExtensionApi;
declare const browser: ExtensionApi | undefined;
