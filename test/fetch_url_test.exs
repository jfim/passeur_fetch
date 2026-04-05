defmodule PasseurFetch.Tools.FetchUrlTest do
  use ExUnit.Case

  test "fetches a URL and returns markdown with headers, images, and bullet lists" do
    result =
      PasseurFetch.Tools.FetchUrl.execute(
        %{url: "https://blog.jean-francois.im/posts/building-a-simple-air-quality-monitor/index.en.html"},
        %{}
      )

    assert {:reply, response, %{}} = result
    [%{"text" => text}] = response.content

    # Contains markdown headers
    assert text =~ ~r/^#/m

    # Contains markdown images
    assert text =~ ~r/!\[.*\]\(.*\)/

    # Contains markdown bullet lists
    assert text =~ ~r/^[\*\-] /m
  end
end
