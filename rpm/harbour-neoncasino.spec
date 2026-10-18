Name:       harbour-neoncasino
Summary:    Cyberpunk casino roguelike: slots, blackjack and roulette
Version:    1.3.0
Release:    1
License:    BSD-2-Clause
BuildArch:  noarch
Source0:    %{name}-%{version}.tar.gz
Requires:   sailfishsilica-qt5 >= 0.10.9
Requires:   libsailfishapp-launcher

%description
Start a run with ¤100 neon credits (play money) and see how high you can climb across
neon slots, blackjack and roulette. Every tier raises the table minimum and
lets you draft a perk; the more you wager over all runs, the more perks you
unlock. No real money, nothing to buy.

%prep
%setup -q

%build

%install
mkdir -p %{buildroot}%{_datadir}/%{name}
cp -r qml %{buildroot}%{_datadir}/%{name}/
install -Dm644 %{name}.desktop %{buildroot}%{_datadir}/applications/%{name}.desktop
for s in 86 108 128 172; do
    install -Dm644 icons/${s}x${s}/%{name}.png %{buildroot}%{_datadir}/icons/hicolor/${s}x${s}/apps/%{name}.png
done

%files
%defattr(-,root,root,-)
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
