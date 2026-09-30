#import "MiOSSectionCardView.h"
#import "../UI/MiOSTheme.h"

@implementation MiOSSectionCardView {
    UILabel *_headerLabel;
    UIView *_cardBg;
}

- (instancetype)initWithTitle:(NSString *)title {
    if (self = [super initWithFrame:CGRectZero]) {
        _sectionTitle = title;
        [self setupView];
    }
    return self;
}

- (void)setupView {
    self.translatesAutoresizingMaskIntoConstraints = NO;

    _headerLabel = [[UILabel alloc] init];
    _headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _headerLabel.text = [_sectionTitle uppercaseString];
    _headerLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    _headerLabel.textColor = [MiOSTheme secondaryText];
    _headerLabel.hidden = (_sectionTitle.length == 0);
    [self addSubview:_headerLabel];

    _cardBg = [[UIView alloc] init];
    _cardBg.translatesAutoresizingMaskIntoConstraints = NO;
    [MiOSTheme applyGlassEffectToView:_cardBg];
    [self addSubview:_cardBg];

    _contentStack = [[UIStackView alloc] init];
    _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.spacing = 0;
    [_cardBg addSubview:_contentStack];

    CGFloat headerHeight = _sectionTitle.length > 0 ? 24 : 0;

    [NSLayoutConstraint activateConstraints:@[
        [_headerLabel.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_headerLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [_headerLabel.heightAnchor constraintEqualToConstant:headerHeight],
        [_cardBg.topAnchor constraintEqualToAnchor:_headerLabel.bottomAnchor constant:_sectionTitle.length > 0 ? 8 : 0],
        [_cardBg.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_cardBg.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_cardBg.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [_contentStack.topAnchor constraintEqualToAnchor:_cardBg.topAnchor],
        [_contentStack.leadingAnchor constraintEqualToAnchor:_cardBg.leadingAnchor],
        [_contentStack.trailingAnchor constraintEqualToAnchor:_cardBg.trailingAnchor],
        [_contentStack.bottomAnchor constraintEqualToAnchor:_cardBg.bottomAnchor],
    ]];
}

- (void)addCellView:(UIView *)cell {
    cell.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentStack addArrangedSubview:cell];
}

- (void)addSeparator {
    UIView *sep = [[UIView alloc] init];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    sep.backgroundColor = [MiOSTheme separator];
    [_contentStack addArrangedSubview:sep];
    [sep.heightAnchor constraintEqualToConstant:0.5].active = YES;
    [sep.leadingAnchor constraintEqualToAnchor:_contentStack.leadingAnchor constant:64].active = YES;
}

- (void)traitCollectionDidChange:(UITraitCollection *)prev {
    [super traitCollectionDidChange:prev];
    _cardBg.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.06].CGColor;
}

@end
